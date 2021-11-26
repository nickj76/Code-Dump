![](https://www.codetriage.com/mallockey/install-office365suite/badges/users.svg)
# Install-Office365Suite

## Updates
9/16/21
* Cleaned up styling and reduced function complexity
* Fixed bug that would cause false reporting on if Office was installed correctly or not
* Added `-CleanUpInstallFiles` parameter
## Description
A PowerShell script that installs Office 365 on a workstation with parameters that talor the install to your specific needs.
## Installing the script

`Install-Script -Name Install-Office365Suite`

## Features
The script will download the Office Deployment Tool from Microsoft's website first. If you have an XML file that you'd like to use you can supply it to the **-ConfigurationXMLFile** parameter like below:

`.\Install-Office365Suite.ps1 -ConfigurationXMLFile "C:\Kits\OfficeConfig.xml"`

If you don't, you can run it without any parameters and it will install with the default settings below:
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