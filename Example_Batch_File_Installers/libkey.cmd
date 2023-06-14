MD C:\Temp\Libkey
Copy "%~dp0*.reg" C:\Temp\Libkey /Y
PUSHD C:\Temp\Libkey
regedit.exe /s libkey.reg
@echo 1.0>C:\Temp\Libkey\Ver1.0.txt
Del C:\Temp\Libkey\*.reg