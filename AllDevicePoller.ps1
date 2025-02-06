# To enable logging to console, uncomment line 36
# To enable logging to C:\your\path\to\log\file.txt, uncomment line 22, 27, 37, 40, 44, 49, and 53
# Define the log file path
$logFile = "C:\your\path\to\log\file.txt"

# Function to log messages
function Log-Message {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value "$timestamp - $message"
}

# Define the security group devices will be added to
$securityGroup = "All Devices"

# Import the Active Directory module if not already imported
Import-Module ActiveDirectory

# Start logging
#Log-Message "Script started."

try {
    # Get all domain-joined computers
    $computers = Get-ADComputer -Filter *
    #Log-Message "Retrieved $($computers.Count) domain-joined computers."

    # Loop through each computer and add it to the security group
    foreach ($computer in $computers) {
        try {
            # Ensure the DistinguishedName property is not null or empty
            if (-not [string]::IsNullOrEmpty($computer.DistinguishedName)) {
                # Add the computer to the security group
                Add-ADGroupMember -Identity $securityGroup -Members $computer.DistinguishedName -ErrorAction Stop
                #Write-Output "Successfully added $($computer.Name) to $securityGroup."
                #Log-Message "Successfully added $($computer.Name) to $securityGroup."
            }
            else {
                #Log-Message "Skipping $($computer.Name) because its DistinguishedName is empty."
            }
        }
        catch {
            #Log-Message "Failed to add $($computer.Name) to $securityGroup. Error: $_"
        }
    }
}
catch {
    #Log-Message "An error occurred while retrieving or processing computers. Error: $_"
}

# End logging
#Log-Message "Script completed."
