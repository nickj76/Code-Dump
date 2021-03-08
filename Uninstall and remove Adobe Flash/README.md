Use this powershell script below to completely uninstall Flash from your computer.
It runs Adobe Uninstaller and removes all other plug-ins/files that may be lingering even after uninstaller run

How it works

This script:

Downloads and runs Adobe Flash removal tool. 

Uninstalls any Flash ActiveX or NPAPI plugins

Removes:

C:\Windows\system32\Macromed\Flash
C:\Windows\SysWow64\Macromed\Flash
%appdata%\Adobe\Flash Player
%appdata%\Macromedia\Flash Player
C:\Windows\SysWOW64\FlashPlayerApp.exe
C:\Windows\SysWOW64\FlashPlayerCPLApp.cpl

Installation

Download flashremoval.zip and extract flashremoval.ps1 file inside to desired location.
e.g. C:\temp

Open Windows Powershell as administrator. (its needs to run as administrator or script will error out)

Run flashremoval.ps1 using the relative path where its downloaded. 

e.g. C:\temp\flashremoval.ps1
or
.\flashremoval.ps1

If you encounter an error regarding running scripts being blocked (ExecutionPolicy):

Run command: Set-ExecutionPolicy Bypass -Force

Then try running flashremoval.ps1 again.

It is also recommended to install standalone Windows update KB4577586 that microsoft released to get rid of Flash.