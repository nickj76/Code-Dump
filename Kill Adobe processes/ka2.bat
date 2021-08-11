REM Kill Adobe processes
taskkill.exe /F /FI "IMAGENAME eq acrotray*"
taskkill.exe /F /FI "IMAGENAME eq acrobat_sl*"
taskkill.exe /F /FI "IMAGENAME eq acro*"
taskkill.exe /F /FI "IMAGENAME eq adobe*"
taskkill.exe /F /FI "IMAGENAME eq adobe *"
taskkill.exe /F /FI "IMAGENAME eq Adobe*"
taskkill.exe /F /FI "IMAGENAME eq AdobeIPCBroker*"
taskkill.exe /F /FI "IMAGENAME eq armsvc*"
taskkill.exe /F /FI "IMAGENAME eq plugin-container*"
taskkill.exe /F /FI "IMAGENAME eq AdobeCollabSync*"
taskkill.exe /F /FI "IMAGENAME eq Creative*"
taskkill.exe /F /FI "IMAGENAME eq Creative *"
taskkill.exe /F /FI "IMAGENAME eq CCXProcess*"
taskkill.exe /F /FI "IMAGENAME eq CCLibrary*"
taskkill.exe /F /FI "IMAGENAME eq Core*"
taskkill.exe /F /FI "IMAGENAME eq CCLibraries*"

exit
