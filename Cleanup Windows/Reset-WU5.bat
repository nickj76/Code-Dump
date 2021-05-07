echo Stopping services
net stop wuauserv
net stop cryptSvc
net stop bits
net stop msiserver

echo Clearing tmp files and failed Windows Update folders
echo.
echo del C:\Windows\SoftwareDistribution.old 
echo del C:\Windows\System32\catroot2.old
echo.
echo Renaming C:\Windows\SoftwareDistribution to SoftwareDistribution.old
echo.
echo Renaming  C:\Windows\System32\catroot2 to Catroot2.old

ren C:\Windows\SoftwareDistribution SoftwareDistribution.old
ren C:\Windows\System32\catroot2 Catroot2.old

del "%tmp%" /s /q 
del "%temp%" /s /q 
del C:\*.tmp /s /q
del C:\Windows\Temp\*

# this is optional and can be enabled / disabled as needed
# Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase

echo Still Working......

takeown /F C:\$Windows.~BT\* /R /A 
icacls C:\$Windows.~BT\*.* /T /grant administrators:F 
rmdir /S /Q C:\$Windows.~BT\

takeown /F C:\$Windows.~WS\* /R /A 
icacls C:\$Windows.~WS\*.* /T /grant administrators:F 
rmdir /S /Q C:\$Windows.~WS\

echo Still Working......

takeown /F C:\users\*\Application Data\SPSSInc\Graphboard* /R /A 
icacls C:\users\*\Application Data\SPSSInc\Graphboard\*.* /T /grant administrators:F 
rmdir /S /Q C:\users\*\Application Data\SPSSInc\Graphboard\

echo Almost Done......

echo starting services
net start wuauserv
net start cryptSvc
net start bits
net start msiserver

echo Done. Press a key to close the window
pause