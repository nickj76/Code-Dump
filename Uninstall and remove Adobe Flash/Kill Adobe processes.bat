REM Kill Adobe processes
taskkill.exe /f /fi “IMAGENAME eq acrotray*”
taskkill.exe /f /fi “IMAGENAME eq acrobat_sl*”
taskkill.exe /f /fi “IMAGENAME eq acro*”
taskkill.exe /f /fi “IMAGENAME eq Adobe*”
taskkill.exe /f /fi “IMAGENAME eq Adobe *”
taskkill.exe /f /fi “IMAGENAME eq armsvc*”
taskkill.exe /f /fi “IMAGENAME eq plugin-container*”
taskkill.exe /f /fi “IMAGENAME eq AdobeCollabSync*”
taskkill.exe /f /fi “IMAGENAME eq Creative*”
taskkill.exe /f /fi “IMAGENAME eq Creative *”
taskkill.exe /f /fi “IMAGENAME eq Adobe*”
taskkill.exe /f /fi “IMAGENAME eq AdobeIPCBroker*”
taskkill.exe /f /fi “IMAGENAME eq CCXProcess*”
taskkill.exe /f /fi “IMAGENAME eq CCLibrary*”
taskkill.exe /f /fi “IMAGENAME eq Core*”
taskkill.exe /f /fi “IMAGENAME eq CCLibraries*”

exit