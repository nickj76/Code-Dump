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

$officeVersion | Add-Member -Name 'Computer Name' -Type NoteProperty -Value $env:COMPUTERNAME

$officeVersion | export-csv -Path C:\Temp\officeVersion.csv -NoTypeInformation -Append


