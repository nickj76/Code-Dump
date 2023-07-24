
Create a scheduled task that runs as SYSTEM and kicks off, which works from inside of Windows. Here is what I did:

1. Pre Installation 

Check if the tasks already exists and delete it (in case of failures\reruns)

2. Installation 

Create the task, kick the task off, and then use a While loop to check if the task is still running (this makes the Show-InstallationProgress prompt stay up so it can pass to Show-InstallationRestartPrompt). Adjust $STExecutable for your location of Setup.exe and $STArguments for your arguments\switches

3. Post-Installation

Cleanup Task

Mote: 

You can use PSADT to personalise things with Show-InstallationWelcome, deferals and deadlines etc. 
Show-InstallationRestartPrompt to reboot after the initial install and edit the XML to let the user know that the next step after reboot may take over an hour. 