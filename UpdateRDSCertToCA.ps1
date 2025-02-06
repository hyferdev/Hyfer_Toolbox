# Define Variables
$CAName = "Your-CA"  # Change this to match your CA name

# Get the CA-issued certificate from Local Machine's Personal Store
$Cert = Get-ChildItem -Path Cert:\LocalMachine\My | 
Where-Object {
    $_.Issuer -like "*$CAName*" -and 
    [string]::IsNullOrEmpty($_.Subject)
} | 
Sort-Object NotAfter -Descending | 
Select-Object -First 1

# Ensure we found a valid CA-issued certificate
if ($Cert) {
    $Thumbprint = $Cert.Thumbprint
    Write-Host "Found CA-issued certificate signed by '$CAName' with Thumbprint: $Thumbprint"

    # Get the RDS settings path
    $PATH = Get-WmiObject -class "Win32_TSGeneralSetting" -Namespace "root\cimv2\terminalservices" -Filter "TerminalName='RDP-Tcp'"

    # Set the new certificate thumbprint using WMI
    Write-Host "Updated RDS Certificate Thumbprint via WMI."
    Set-WmiInstance -Path $PATH.__Path -Argument @{SSLCertificateSHA1Hash = $Thumbprint}
    Write-Host "RDS certificate updated successfully!"
} else {
    Write-Host "No certificate found signed by '$CAName'. Ensure the correct certificate is installed."
}
