# Define Variables
$BucketName = "your-bucket\container"
$DirectoryPath = "D:\your-outbound-directory"
$ArchivePath = "D:\your-archive"
$LogPath = "D:\your-logs"
$ServiceAccountKey = "path-to-your-gcs-key.json"
$LogFile = "$LogPath\upload_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

# Email Settings
$SMTPServer = "your-mailserver.domain.local"
$SMTPPort = 25
$FromEmail = "from-email"
$ToEmail = @("email1@domain.com", "email2@domain.com", "distributionList1@domain.com", "distributionList2@domain.com")
$Subject = "GCS Upload Report - Completed on $(Get-Date -Format 'yyyy-MM-dd')"

# Ensure Archive and Log directories exist
if (!(Test-Path -Path $ArchivePath)) { New-Item -ItemType Directory -Path $ArchivePath -Force | Out-Null }
if (!(Test-Path -Path $LogPath)) { New-Item -ItemType Directory -Path $LogPath -Force | Out-Null }

# Set Google Cloud Authentication
$env:GOOGLE_APPLICATION_CREDENTIALS = $ServiceAccountKey

# Authenticate using the service account
Write-Host "Authenticating with service account..."
gcloud auth activate-service-account --key-file="$ServiceAccountKey" *>$null

# Verify authentication
Write-Host "Verifying authentication..."
gcloud auth list *>$null

# Upload all files & folders recursively
Write-Host "Uploading files and folders to GCS bucket: $BucketName"
$Files = Get-ChildItem -Path $DirectoryPath -Recurse -File

foreach ($File in $Files) {
    $FilePath = $File.FullName

    # Convert Windows path to GCS-friendly path
    $RelativePath = $File.FullName.Substring($DirectoryPath.Length + 1) -replace '\\', '/'
    $GCSPath = "gs://$BucketName/$RelativePath"

    Write-Host "Uploading $FilePath to $GCSPath..."
    gcloud storage cp "$FilePath" "$GCSPath" *>$null

    # Log the successful upload
    "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) - Uploaded: $RelativePath" | Out-File -Append -Encoding utf8 $LogFile
}

# Move only files (not folders) to the archive folder, replicating structure
Write-Host "Moving uploaded files to archive..."
foreach ($File in $Files) {
    $RelativePath = $File.FullName.Substring($DirectoryPath.Length + 1) -replace '\\', '/'  # Maintain folder structure
    $ArchiveDestination = Join-Path $ArchivePath $RelativePath

    # Ensure the destination folder exists
    $ArchiveFolder = Split-Path -Path $ArchiveDestination -Parent
    if (!(Test-Path -Path $ArchiveFolder)) { New-Item -ItemType Directory -Path $ArchiveFolder -Force | Out-Null }

    # Move the file to the corresponding archive folder
    Move-Item -Path $File.FullName -Destination $ArchiveDestination -Force
}

Write-Host "All files uploaded and archived successfully!"
Write-Host "Log file saved at: $LogFile"

# Send Email with Log File
if (Test-Path $LogFile) {
    Write-Host "Sending email with log file..."

    $EmailBody = "The daily Stealth GCS upload has completed successfully. Please find the log attached."

    $Message = New-Object System.Net.Mail.MailMessage
    $Message.From = $FromEmail
    foreach ($Recipient in $ToEmail) {
        $Message.To.Add($Recipient)
    }
    $Message.Subject = $Subject
    $Message.Body = $EmailBody
    $Message.Attachments.Add($LogFile)

    $SMTP = New-Object Net.Mail.SmtpClient($SMTPServer, $SMTPPort)
    $SMTP.Send($Message)

    Write-Host "Email sent successfully to: $($ToEmail -join ', ')"
} else {
    Write-Host "No files were uploaded. Sending email alert..."

    $EmailBody = "No files were uploaded to Stealth GCS during the scheduled task."

    $Message = New-Object System.Net.Mail.MailMessage
    $Message.From = $FromEmail
    foreach ($Recipient in $ToEmail) {
        $Message.To.Add($Recipient)
    }
    $Message.Subject = "GCS Upload Report - No Files Uploaded"
    $Message.Body = $EmailBody

    $SMTP = New-Object Net.Mail.SmtpClient($SMTPServer, $SMTPPort)
    $SMTP.Send($Message)

    Write-Host "Email sent successfully to: $($ToEmail -join ', ')"
}
