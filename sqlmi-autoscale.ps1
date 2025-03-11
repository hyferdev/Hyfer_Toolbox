# Run under an automation account. System assigned identity of the automation account has to have contributor rights on the SQL Managed Instances.
# Runbook type: Powershell 5.1 

param (
    [string]$subscriptionId = "your-subscription-id",
    [string]$resourceGroupName = "your-resource-group",
    [array]$sqlManagedInstances = @("sqlmi-01", "sqlmi-02", "sqlmi-03"),
    [int]$targetUtilization = 75  # Bring storage usage back to 75%
    [int]$targetUtilization = 75,  # Bring storage usage back to 75%
    [int]$scaleThreshold = 90,  # Scale storage when usage exceeds 90%
    [string]$logicAppUrl = "your-logic-app-url"  # Logic App URL
)

# Connect to Azure
$AzureContext = (Connect-AzAccount -Identity).Context
# Set the correct subscription
Set-AzContext -SubscriptionId $subscriptionId

# Function to round storage size to the nearest 32GB multiple
function Round-UpToMultipleOf32GB {
    param (
        [int]$sizeGB
    )
    return [math]::Ceiling($sizeGB / 32) * 32
}

# Function to send an email via Logic App
function Send-EmailNotification {
    param (
        [string]$sqlMI,
        [int]$currentStorage,
        [int]$newStorage,
        [double]$currentUsage
    )

    # Email Subject & Body
    $emailSubject = "SQL MI Storage Increased for $sqlMI"
    $emailBody = "SQL Managed Instance: $sqlMI storage was increased from $currentStorage GB to $newStorage GB due to reaching $currentUsage% utilization."

    # JSON Payload for Logic App
    $payload = @{
        "subject" = $emailSubject
        "body" = $emailBody
    } | ConvertTo-Json -Depth 10

    # Call Logic App via HTTP Request
    try {
        $response = Invoke-RestMethod -Uri $logicAppUrl -Method Post -Headers @{
            "Content-Type"  = "application/json"
        } -Body $payload

        Write-Output "✅ Email notification successfully triggered via Logic App for $sqlMI!"
    } catch {
        Write-Output ("❌ Failed to trigger Logic App for {0}: {1}" -f $sqlMI, $_)
    }
}

foreach ($sqlMI in $sqlManagedInstances) {
    try {
        # Get SQL MI Resource
        $mi = Get-AzSqlInstance -ResourceGroupName $resourceGroupName -Name $sqlMI
        $currentStorage = $mi.StorageSizeInGB

        # Fetch Storage Usage (in MB)
        $metricData = Get-AzMetric -ResourceId $mi.Id -MetricName "storage_space_used_mb" -AggregationType Maximum -TimeGrain 00:05:00 -WarningAction SilentlyContinue

        if ($metricData.Data.Count -gt 0) {
            # Get the most recent metric value
            $latestMetric = $metricData.Data | Sort-Object TimeStampUTC -Descending | Select-Object -First 1
            $usedStorageGB = $latestMetric.Maximum / 1024  # Convert MB to GB
            $currentUsage = ($usedStorageGB / $currentStorage) * 100  # Calculate storage utilization %
        } else {
            Write-Output "No storage metric data found for $sqlMI"
            continue
        }

        # Scale storage if utilization exceeds the threshold (90%)
        if ($currentUsage -ge $scaleThreshold) {
            # Calculate New Storage to Reduce Usage to 75%
            $newStorage = [math]::Ceiling($usedStorageGB / ($targetUtilization / 100))

            # Ensure storage is in multiples of 32GB
            $newStorage = Round-UpToMultipleOf32GB -sizeGB $newStorage

            # Ensure min/max storage limits
            if ($newStorage -lt 32) { $newStorage = 32 }
            if ($newStorage -gt 16384) { $newStorage = 16384 }

            # Update SQL MI Storage
            Write-Output "Scaling SQL MI: $sqlMI - Increasing storage from $currentStorage GB to $newStorage GB due to reaching $currentUsage% utilization."
            Set-AzSqlInstance -ResourceGroupName $resourceGroupName -Name $sqlMI -StorageSizeInGB $newStorage -Confirm:$false -Force

            # Send Email Notification using Logic App
            Send-EmailNotification -sqlMI $sqlMI -currentStorage $currentStorage -newStorage $newStorage -currentUsage $currentUsage

            Write-Output "SQL MI: $sqlMI - Storage successfully increased to $newStorage GB. Email notification sent via Logic App."
        } else {
            Write-Output "SQL MI: $sqlMI - Utilization at $currentUsage%, no scaling needed."
        }
    } catch {
        Write-Output ("Error processing SQL MI {0}: {1}" -f $sqlMI, $_)
    }
}
