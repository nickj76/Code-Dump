echo Stopping services
net stop wuauserv
net stop cryptSvc
net stop bits
net stop msiserver

echo Clearing tmp files and failed Windows Update folders

del "%tmp%" /s /q 
del "%temp%" /s /q 
del C:\*.tmp /s /q
del C:\users\*\AppData\Local\Temp\*
del C:\Windows\Temp\*
Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase

echo.
echo Renaming C:\Windows\SoftwareDistribution SoftwareDistribution to .old
echo.
echo Renaming  C:\Windows\System32\catroot2 Catroot2

ren C:\Windows\SoftwareDistribution SoftwareDistribution.old
ren C:\Windows\System32\catroot2 Catroot2.old

echo Still Working......

takeown /F C:\$Windows.~BT\* /R /A 
icacls C:\$Windows.~BT\*.* /T /grant administrators:F 
rmdir /S /Q C:\$Windows.~BT\

takeown /F C:\$Windows.~WS\* /R /A 
icacls C:\$Windows.~WS\*.* /T /grant administrators:F 
rmdir /S /Q C:\$Windows.~WS\

echo Almost done......

echo starting services
net start wuauserv
net start cryptSvc
net start bits
net start msiserver


echo Done. Press a key to close the window
pause