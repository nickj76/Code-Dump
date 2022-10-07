# Define paths where Office could be located
$paths = @(
    "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\ClickToRun"
)

# Variable to hold version
$officeVersion = ""

# Loop through paths and find version
foreach ($path in $paths) {
    # Check to see if path exists
    if (Test-Path -Path "$path\Configuration") {
        $officeVersion = (Get-ItemProperty -Path "$path\Configuration" -Name "VersionToReport").VersionToReport
    }
}

Write-Output $officeVersion
Exit 0

