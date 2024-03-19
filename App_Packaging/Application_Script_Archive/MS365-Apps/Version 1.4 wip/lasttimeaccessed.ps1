$lasttimeaccess = Get-ChildItem "C:\Program Files (x86)\Microsoft Office\root\Office16\MSACCESS.EXE" | Select-Object lastaccesstime

Write-output $lasttimeaccess


