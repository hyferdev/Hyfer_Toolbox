# === DESCRIPTION ===
# Retrieves all users from AD, filters them, and uploads CSV to Azure Blob Storage.

# === REQUIREMENTS ===
# Powershell 7+
# Must run on an Azure VM or resource with a System-Assigned Managed Identity
# Permissions needed:
#   AD Reader
#   Storage: Storage Blob Data Contributor (or higher) on the container

# =================== SET THESE ===================
$storageAccount = "<your storage account>"
$containerName  = "<your container>"
$blobName       = "<name of your output csv>"
$tempFolder     = "C:\Temp"
$tempFile       = Join-Path $tempFolder $blobName
# =================================================

# Load AD Module (Hybrid Worker must have RSAT)
Import-Module ActiveDirectory

# Define the OUs to exclude (and their sub-OUs)
$excludedOUs = "OU=Disabled Users,OU=Disabled Group,OU=Site,OU=Test OU Main,DC=lazydays,DC=local"

## Get all enabled users in the domain
$allUsersRaw = Get-ADUser -Filter { Enabled -eq $true } `
    -Properties DisplayName,EmployeeID,Title,Department,Manager,Mail,LastLogonTimeStamp,DistinguishedName,SamAccountName

# Convert exclusion to uppercase
$excludedOUs = $excludedOUs.ToUpper()

# Exclude users in the specified OU and its sub-OUs
$allUsers = $allUsersRaw | Where-Object {
    $_.DistinguishedName.ToUpper() -notlike "$excludedOUs*"
}


# Build user list
$results = foreach ($user in $allUsers) {
    $managerName = $null
    if ($user.Manager) {
        try {
            $managerName = (Get-ADUser $user.Manager -Properties DisplayName).DisplayName
        } catch {}
    }

    $ou = ($user.DistinguishedName -replace '^CN=.*?,', '')

    [PSCustomObject]@{
        EmployeeID         = $user.EmployeeID
        SamAccountName     = $user.SamAccountName
        DisplayName        = $user.DisplayName
        LastLogonTimeStamp = if ($user.LastLogonTimeStamp) { [DateTime]::FromFileTime($user.LastLogonTimeStamp) } else { "" }
        Mail               = $user.Mail
        Manager            = $managerName
        Title              = $user.Title
        Department         = $user.Department
        OU                 = $ou
    }
}

# Export to CSV
New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null
$results | Export-Csv -Path $tempFile -NoTypeInformation -Force

if (-not (Test-Path $tempFile)) {
    throw "[ERROR] CSV file not created: $tempFile"
}

# === Get Storage Token ===
$storageToken = (Invoke-RestMethod -Headers @{Metadata="true"} `
    -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://storage.azure.com" `
    -Method GET).access_token

if (-not $storageToken) {
    throw "[ERROR] Failed to retrieve Storage token."
}

# === Upload to Azure Blob ===
$uploadHeaders = @{
    Authorization    = "Bearer $storageToken"
    "x-ms-blob-type" = "BlockBlob"
    "x-ms-version"   = "2020-04-08"
}

$uri = "https://$storageAccount.blob.core.windows.net/$containerName/$blobName"

try {
    $response = Invoke-WebRequest -Uri $uri -Headers $uploadHeaders -Method Put -InFile $tempFile
    if ($response.StatusCode -eq 201) {
        Write-Host "[SUCCESS] Upload successful: $uri"
    } else {
        Write-Host "[INFO] Upload returned: $($response.StatusCode) $($response.StatusDescription)"
    }
} catch {
    Write-Host "[ERROR] Upload failed: $($_.Exception.Message)"
}
