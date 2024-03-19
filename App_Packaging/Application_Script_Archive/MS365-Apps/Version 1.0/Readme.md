## Scripts to Remove Office C2R and Install Microsoft Apps 365 for Enterprise
## Updates

2/12/21
* Created a script to create a "seeder" key which creates or modifies a user-based registry value for all users on a computer, in order to suppress the pop up about "Your Privacy Matters" 

1/12/21
* Created script to stop running office applications gracefully, users are now prompted to save work before the application will close.
* Created script to run toast notification warning user of incoming upgrade.

30/11/21
* Pointed to specific xml config file (See line 141).

29/11/21
* Cleaned up styling and reduced function complexity.
* Fixed bug that would cause false reporting on if Office was installed correctly or not.
* Added `-CleanUpInstallFiles` parameter.

## Description
A collection of PowerShell scripts that remove office C2R and install Office 365 using parameters specified in the XML files (Install-MS-Apps-365.xml & Remove-Office.xml). 

## Features
These scripts will remove office c2r and install Microsoft Apps 365 for Enterprise using the Office Deployment Tool from Microsoft's website first. The XML file location and name is set on line 141 of Install-Office365 & Remove-Office PS1 files.

`.\Install-Office365.ps1`

If you remove the xml file, you can run it without any parameters and it will install with the default settings below:
```xml
<Configuration>
  <Add OfficeClientEdition="64" Channel="Broad">
    <Product ID="O365ProPlusRetail">
      <Language ID="MatchOS" />
    </Product>
  </Add>
  <Property Name="PinIconsToTaskbar" Value="TRUE" />
  <Property Name="SharedComputerLicensing" Value="0" />
  <Display Level="None" AcceptEULA="TRUE" />
  <Updates Enabled="TRUE" />
  <RemoveMSI />
</Configuration>`
```

Alternatively, you can set many settings from the command line that you'd like to include, below is a list of the settings and their values:

 Parameter | Possible Values 
--- | --- |
-AcceptEULA | TRUE,FALSE
-Channel | Broad, Targeted, Monthly
-DisplayInstall | [Switch]
-EnableUpdates | TRUE, FALSE
-ExcludeApps | Groove, Outlook, OneNote, Access, OneDrive, Publisher, Word, Excel, PowerPoint, Teams, Lync
-OfficeArch | 64, 32
-OfficeEdition | O365ProPlusRetail, O365BusinessRetail
-OfficeInstallerDownloadPath   | [String] *Specify path*
-SharedComputerLicensing | 0,1
-LoggingPath | [String] *Specify path*
-SourcePath | [String] *Specify path*
-PinItemsToTaskbar  | TRUE, FALSE
-KeepMSI | [Switch]
-CleanUpInstallFiles | [Switch]

## Additional Info
By default, the script will create and download the ODT tool to "C:\Scripts\Office365Install" folder. You can change this with the **-OfficeInstallDownloadPath** parameter
