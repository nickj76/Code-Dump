AutoDesk Inventor 2017 Install
Configurations for installing AutoDesk Inventor 2017 with SCCM. Due to the size of the standard installer (7-10 GB, or more, I don't remember), the installation process is sped up by compressing the contents, then sending the package/deployment to the machine, uncompressing and installing. Package will require 20-30 GB of total free space for the uncompressing.

However, if you're installing this on a machine that struggles with that much free space, perhaps you consider upgrading the machine and/or hard drive/SSD. ;-)

Requirements
7z.exe (7-Zip executable)
7z.dll
Compressed AutoDesk Inventor 2017 install package in .7z format
Preconfigured AutoDesk Inventor .INI file for customization
SCCM Install Notes
Configure install/uninstall programs as the batch files
Detection method: Up to you. I used "%ProgramFiles%\Autodesk\Inventor 2017\Bin" with inventor.exe as file (chose this because these workstations don't get program upgrades; we just reimage them)
Note: this is also a template for using 7-Zip to deploy large packages/applications with SCCM.