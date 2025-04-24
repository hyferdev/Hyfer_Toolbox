# === DESCRIPTION ===
# Retrieves all users via Graph API, filters them, and uploads CSV to Azure Blob Storage.

# === REQUIREMENTS ===
# Powershell 7+
# Must run on an Azure VM or resource with a System-Assigned Managed Identity
# Permissions needed:
#   Microsoft Graph: User.Read.All
#   Storage: Storage Blob Data Contributor (or higher) on the container

# === CONFIGURATION ===
$storageAccount = "<your storage account>"
$containerName  = "<your container>"
$blobName       = "<name of your output csv>"
$tempFolder     = "C:\Temp"
$tempFile       = Join-Path $tempFolder $blobName

# === Step 1: Get access token for Microsoft Graph ===
$graphToken = (Invoke-RestMethod -Headers @{Metadata="true"} `
    -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://graph.microsoft.com" `
    -Method GET).access_token

if (-not $graphToken) {
    throw "❌ Failed to retrieve Graph API token."
}

$graphHeaders = @{ Authorization = "Bearer $graphToken" }

# === Step 2: Pull all groups ===
$url = "https://graph.microsoft.com/v1.0/groups"
$allGroups = @()

do {
    $response = Invoke-RestMethod -Uri $url -Headers $graphHeaders -Method Get
    $allGroups += $response.value
    $url = $response.'@odata.nextLink'
} while ($url)

# === Step 3: Export to CSV ===
New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null
$allGroups | Select-Object id, displayName, description, mail, mailEnabled, securityEnabled `
    | Export-Csv -Path $tempFile -NoTypeInformation -Force

if (-not (Test-Path $tempFile)) {
    throw "❌ CSV file not created: $tempFile"
}

# === Step 4: Get token for Azure Storage ===
$storageToken = (Invoke-RestMethod -Headers @{Metadata="true"} `
    -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://storage.azure.com" `
    -Method GET).access_token

if (-not $storageToken) {
    throw "❌ Failed to retrieve Storage token."
}

# === Step 5: Upload CSV to Blob Storage ===
$uploadHeaders = @{
    Authorization    = "Bearer $storageToken"
    "x-ms-blob-type" = "BlockBlob"
    "x-ms-version"   = "2020-04-08"
}

$uri = "https://$storageAccount.blob.core.windows.net/$containerName/$blobName"

try {
    $response = Invoke-WebRequest -Uri $uri -Headers $uploadHeaders -Method Put -InFile $tempFile
    if ($response.StatusCode -eq 201) {
        Write-Host "✅ Upload successful: $uri"
    } else {
        Write-Host "⚠️ Upload returned: $($response.StatusCode) $($response.StatusDescription)"
    }
} catch {
    Write-Host "❌ Upload failed: $($_.Exception.Message)"
}
