# Define parameters
$computerName = "localhost" # Change this to your target computer name
$shutdownTime = 60 # Time in seconds before shutdown
$messageText = "Your computer will shut down in $shutdownTime seconds. Do you want to delay it by 20 minutes?" # Change this to your desired message text
$messageTitle = "Shutdown Notification" # Change this to your desired message title
$yesButton = 6 # Button code for Yes
$noButton = 7 # Button code for No

# Load assembly for message box
Add-Type -AssemblyName PresentationFramework

# Display message box and get user input
$result = [System.Windows.MessageBox]::Show($messageText,$messageTitle,$yesButton,$noButton)

# Check user input and perform action accordingly
if ($result -eq $yesButton) {
    # User clicked Yes, delay shutdown by 20 minutes (1200 seconds)
    shutdown /s /t 1200 /m \\$computerName /c "Shutdown delayed by 20 minutes"
}
elseif ($result -eq $noButton) {
    # User clicked No, shutdown immediately
    shutdown /s /t 0 /m \\$computerName /c "Shutdown now"
}
else {
    # User did not click any button, shutdown after specified time
    shutdown /s /t $shutdownTime /m \\$computerName /c "Shutdown in $shutdownTime seconds"
}