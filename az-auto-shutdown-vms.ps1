# Run under an automation account. System assigned identity of the automation account has to have contributor rights on the SQL Managed Instances.
# Runbook type: Powershell 5.1 

# Parameters
param (
    [string]$LogicAppUrl = "your-logic-app-url",  # Replace with your Logic App URL
    [string]$EmailSubject = "Azure VM Shutdown Notification",
    [bool]$SkipTaggedVMs = $true  # Set to $false if you want to ignore the 'no_shut' tag check
)


# Authenticate using the system-assigned managed identity
try {
    Connect-AzAccount -Identity
} catch {
    Write-Error "Could not authenticate to Azure. Ensure that the Automation Account's managed identity has the necessary permissions."
    throw $_
}

# Get all resource groups
$resourceGroups = Get-AzResourceGroup

# Iterate through each resource group
foreach ($resourceGroup in $resourceGroups) {
    $resourceGroupName = $resourceGroup.ResourceGroupName
    Write-Output "Processing Resource Group: $resourceGroupName"
    
    # Get all VMs in the current resource group
    $vms = Get-AzVM -ResourceGroupName $resourceGroupName -Status
    
    # Stop each VM in the resource group if running
    foreach ($vm in $vms) {
        # Check if the VM has the 'no_shut' tag with value set to 'true'
        $tags = $vm.Tags
        if ($SkipTaggedVMs -and $tags.ContainsKey("no_shut") -and $tags["no_shut"] -eq "true") {
            Write-Output "Skipping VM: $($vm.Name) in Resource Group: $resourceGroupName due to 'no_shut' tag set to 'true'."
            continue
        }

        # Check VM PowerState
        $vmStatus = ($vm | Get-AzVM -Status).Statuses | Where-Object { $_.Code -match "PowerState" }
        $powerState = $vmStatus.Code -replace "PowerState/", ""  # Extracting clean state value

        if ($powerState -eq "stopped" -or $powerState -eq "deallocated") {
            Write-Output "Skipping VM: $($vm.Name) as it is already $powerState."
            continue
        }

        # Stop the VM
        Write-Output "Stopping VM: $($vm.Name) in Resource Group: $resourceGroupName"
        Stop-AzVM -ResourceGroupName $resourceGroupName -Name $vm.Name -Force
        Write-Output "VM $($vm.Name) in Resource Group $resourceGroupName stopped successfully."

        # Construct JSON payload to match the Logic App schema
        $body = @{
            "subject" = $EmailSubject
            "body" = "The VM '$($vm.Name)' in Resource Group '$resourceGroupName' has been shut down."
        } | ConvertTo-Json -Depth 2  # Ensuring JSON formatting

        # Send notification to Logic App
        try {
            Invoke-RestMethod -Uri $LogicAppUrl -Method Post -Body $body -ContentType "application/json"
            Write-Output "Email notification sent for VM: $($vm.Name)"
        } catch {
            Write-Error "Failed to send email notification for VM: $($vm.Name). Error: $_"
        }
    }
}
