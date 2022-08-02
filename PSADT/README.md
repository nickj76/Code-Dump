This is a small gist with snippits I frequently use in [PSADT - PowerShell App Deployment Toolkit](http://psappdeploytoolkit.com).

Feel free to offer suggestions, if code I've provided no longer works, doesn't work with current windows versions, or if PSADT has provided native functionality for some of my 'PSADT adjacent' code, 

I've also stole a few [from here to get started](http://www.scriptersinc.com/psadt-quick-reference-functions-list/), I've populated a bunch I use regularly.

Also, additional note that isn't strictly related to PSADT, but is helpful in deployment matters.. I've included an z_Example_App.exe.manifest file. From what I can see, when you come across a legacy app that requests administrator privilege on launch (but does not have 'run as administrator' checked in it's properties, you can overrule this behaviour by creating .exe.manifest file (named in accordance with the .exe's file name, e.g. notepad.exe.manifest), with the following within the file:

    <requestedExecutionLevel level="asInvoker" uiAccess="false"/>
    
As opposed to:

    <requestedExecutionLevel level="requireAdministrator" uiAccess="false"/>

See example in this repo, or read more [here](http://www.samlogic.net/articles/manifest.htm) and [here](https://msdn.microsoft.com/en-us/library/aa374191(v=vs.85).aspx)