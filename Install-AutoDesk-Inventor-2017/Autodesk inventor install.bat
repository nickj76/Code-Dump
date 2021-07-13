@echo off
pushd "%~dp0"

start /wait "" 7z.exe x "%cd%\Inventor2017.7z" -o"c:\InventorTemp" -y

:==============================
:AutoDesk Inventor 2017 Install
:==============================

C:\Inventortemp\Img\Setup.exe /W /q /I C:\Inventortemp\Img\AutoDesk Inventor 2017.ini /language en-us

rd "c:\InventorTemp" /s /q

exit /b 0