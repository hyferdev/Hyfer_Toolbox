# --- SFTP CONFIGURATION ---
$SftpHost = "host"
$SftpUsername = "username"
$SshHostKeyFingerprint = "sshfingerprint"
$passwordFile = "encryptedSFTPPassword file"
# Use the following command to create the password file 'Read-Host -AsSecureString | Export-Clixml -Path "encryptedSFTPPassword file'"
$winscpDllPath = "C:\Program Files (x86)\WinSCP\WinSCPnet.dll" # Path to WinSCPnet.dll, you may need to isntall WinSCPnet
$logDir = "logsDirectory"
$logFile = Join-Path $logDir ("sftp-upload-log_" + (Get-Date -Format "yyyy-MM-dd") + ".log") # Log file format
$localRoot = "outboundDirectory"
$remoteRoot = "remoteDirectory"
$archiveRoot = "archiveDirectory"
$subfolders = Get-ChildItem -Path $localRoot -Directory # Can be defined or left dynamic

# --- SMTP CONFIGURATION ---
# Using Office 365 SMTP Connector, but can be altered to work with any mail server
$emailFrom = "fromEmail"
$emailTo = "sendToEmail"
$emailSubject = "SFTP Upload Log - $(Get-Date -Format 'yyyy-MM-dd')"
$emailSmtpServer = "smtp.office365.com"
$emailPort = 587
$emailUser = "smtpEmail"  # Must have SMTP AUTH enabled and have send as permissions on fromEmail if different
$emailPasswordFile = "encryptedSMTPPassword file"

if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# --- LOGGING SETUP ---

$sessionLog = @()

function Write-Log {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp - $Message"
    $line | Out-File -FilePath $logFile -Append -Encoding utf8
    $script:sessionLog += $line
}

Write-Log "[INFO] Starting SFTP connection script..."

# --- DECRYPT PASSWORD ---

try {
    $SecurePassword = Import-Clixml -Path $passwordFile
    $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
    )
    Write-Log "[SUCCESS] Password successfully decrypted from secure file."
}
catch {
    Write-Log "[ERROR] Failed to read or decrypt password: $_"
    throw
}

# --- LOAD WinSCP ASSEMBLY ---

try {
    Add-Type -Path $winscpDllPath
    Write-Log "[SUCCESS] WinSCP .NET assembly loaded."
}
catch {
    Write-Log "[ERROR] Failed to load WinSCP .NET assembly: $_"
    throw
}

# --- SESSION OPTIONS ---

$sessionOptions = New-Object WinSCP.SessionOptions -Property @{
    Protocol              = [WinSCP.Protocol]::Sftp
    HostName              = $SftpHost
    UserName              = $SftpUsername
    Password              = $PlainPassword
    SshHostKeyFingerprint = $SshHostKeyFingerprint
}

$session = New-Object WinSCP.Session

# --- FILE TRANSFER LOGIC ---

try {
    Write-Log "[INFO] Attempting to connect to $SftpHost..."
    $session.Open($sessionOptions)
    Write-Log "[SUCCESS] SFTP connection to $SftpHost successful."

    $subfolders = Get-ChildItem -Path $localRoot -Directory
    foreach ($folder in $subfolders) {
        $localFolderPath = $folder.FullName
        $remoteFolderPath = "/in/$($folder.Name)"

        try {
            Write-Log "[INFO] Creating remote directory: $remoteFolderPath"
            $session.CreateDirectory($remoteFolderPath)

            $files = Get-ChildItem -Path $localFolderPath -File
            foreach ($file in $files) {
                $localFilePath = $file.FullName
                $remoteFilePath = "$remoteFolderPath/$($file.Name)"

                Write-Log "[INFO] Uploading $localFilePath to $remoteFilePath..."
                $transferResult = $session.PutFiles($localFilePath, $remoteFilePath, $false)

                if ($transferResult.IsSuccess) {
                    Write-Log "[SUCCESS] Uploaded: $localFilePath → $remoteFilePath"

                    $archiveFolderPath = Join-Path $archiveRoot $folder.Name
                    if (-not (Test-Path $archiveFolderPath)) {
                        New-Item -ItemType Directory -Path $archiveFolderPath -Force | Out-Null
                        Write-Log "[INFO] Created archive folder: $archiveFolderPath"
                    }

                    $destinationPath = Join-Path $archiveFolderPath $file.Name
                    Move-Item -Path $localFilePath -Destination $destinationPath -Force
                    Write-Log "[INFO] Moved $localFilePath to archive: $destinationPath"
                }
                else {
                    Write-Log "[ERROR] Upload failed for: $localFilePath"
                }
            }
        }
        catch {
            Write-Log "[ERROR] Error processing folder '$($folder.Name)': $_"
        }
    }
}
catch {
    Write-Log "[ERROR] SFTP connection failed: $_"
}
finally {
    $session.Dispose()
    Write-Log "[INFO] SFTP session closed."
}

# --- SEND EMAIL ---

try {
    $secureEmailPassword = Import-Clixml -Path $emailPasswordFile
    $smtpCred = New-Object System.Management.Automation.PSCredential ($emailUser, $secureEmailPassword)
    $logBody = $sessionLog -join "`n"

    if (-not $logBody) {
        $logBody = "[INFO] No log entries were captured during this session."
    }

    Send-MailMessage -From $emailFrom `
                     -To $emailTo `
                     -Subject $emailSubject `
                     -Body $logBody `
                     -SmtpServer $emailSmtpServer `
                     -Port $emailPort `
                     -UseSsl `
                     -Credential $smtpCred

    Write-Log "[SUCCESS] Log email sent to $emailTo."
}
catch {
    Write-Log "[ERROR] Failed to send email: $_"
}
