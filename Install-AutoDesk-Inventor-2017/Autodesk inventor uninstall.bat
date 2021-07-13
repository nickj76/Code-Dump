@echo off

::The following command lines allow un-installing products that were installed using this admin image
:: Notes on suggested usage: 
::     + Copy the commands to a batch file to execute.
::     + The commands must be run with Administrative Privileges, e.g. right-click when opening Command Prompt and accept UAC

::========================================================================================
::Prepare uninstallation's command-line options
::========================================================================================

::Set the output file for uninstallation's log data
::DEFAULT: a log file with the same filename but with extension .log
::         is created in the Windows temporary folder (environment variable TEMP)
set msi_log_file_path="%TEMP%\%~n0.log"
::Delete the current log file
if exist %msi_log_file_path% del /Q %msi_log_file_path%

::Set the path for the network log file
set network_log_folder="\\SCCMSOURCES\Apps\Autodesk\AutoDesk Inventor 2017\Logs\"
::md %network_log_folder%
set network_log_file_path="%network_log_folder%%~n0_Admin.log"
echo ========================== %Date% %Time% =========================== >> %network_log_file_path%
echo Uninstallation Started on Computer Name: %COMPUTERNAME%, Username: %USERNAME%, Domain: %USERDNSDOMAIN% >> %network_log_file_path%

::DEFAULT: silent uninstallation
set non_silent_mode=/norestart /L*+ %msi_log_file_path% REMOVE=ALL REBOOT=ReallySuppress ADSK_SETUP_EXE=1
set silent_mode=/quiet %non_silent_mode%
set uninstallation_mode=%silent_mode%

::========================================================================================
::Helper Functions
::========================================================================================
goto END_FUNCTIONS_SECTION_
:BEGIN_FUNCTIONS_SECTION_

::---------------------------------
::Performs uninstallation and reports failure in the Network Log File
::---------------------------------
:funcUninstall
  setlocal
  set msi_ERROR_SUCCESS=0
  set product_code=%~1
  set product_name=%~2
  msiexec /uninstall %product_code% %uninstallation_mode%

  if %errorlevel%==%msi_ERROR_SUCCESS% goto SUCCESS_

  :ERROR_
    ::------------------------------------------
    ::print out Machine Name, product code, product name
    ::to the network log file for the product that failed to uninstall
    set uninstallation_result=Failed, Result=%errorlevel%
    goto DONE_

  :SUCCESS_
    set uninstallation_result=Succeeded
    goto DONE_

  :DONE_
    echo %Date% %Time% %USERNAME% %COMPUTERNAME% Uninstall %product_name% (Product Code: %product_code%) %uninstallation_result% >> %network_log_file_path%
  endlocal
GOTO:EOF

:END_FUNCTIONS_SECTION_

::========================================================================================
::Uncomment (by removing the ::) the command lines below to uninstall products
::========================================================================================

::::== Microsoft Visual C++ 2008 SP1 Redistributable (x64) 9.0.30729.6161
::::Manual uninstallation only

::::== Microsoft Visual C++ 2008 SP1 Redistributable (x86) 9.0.30729.6161
::::Manual uninstallation only

::::== Microsoft Visual C++ 2010 SP1 Redistributable (x64)
::::Manual uninstallation only

::::== Microsoft Visual C++ 2010 SP1 Redistributable (x86)
::::Manual uninstallation only

::::== Microsoft Visual C++ 2012 Redistributable (x86) Update 4
::::Manual uninstallation only

::::== Microsoft Visual C++ 2012 Redistributable (x64) Update 4
::::Manual uninstallation only

::::== Microsoft Visual C++ 2013 Redistributable (x86)
::::Manual uninstallation only

::::== Microsoft Visual C++ 2013 Redistributable (x64)
::::Manual uninstallation only

::::== Universal C Runtime (KB3118401)
::::Manual uninstallation only

::::== Microsoft Visual C++ 2015 Redistributable (x86) Update 1
::::Manual uninstallation only

::::== Microsoft Visual C++ 2015 Redistributable (x64) Update 1
::::Manual uninstallation only

::::== .NET Framework Runtime 4.6
::::Manual uninstallation only

::::== Microsoft Visual Basic for Applications 7.1 (x64)
::::Manual uninstallation only

::::== Microsoft Visual Basic for Applications 7.1 (x64) English
::::Manual uninstallation only

::::== Microsoft Visual Basic for Applications 7.1 (x64) English
::::Manual uninstallation only

::::== MSXML 6.0 Parser
::::Manual uninstallation only

::::== Microsoft Windows Media Format 9.5 Series Runtime
::::Manual uninstallation only

::::== Microsoft Visual C++ 2008 SP1 Redistributable (x86)
::::Manual uninstallation only

::::== Autodesk Material Library 2017
call :funcUninstall {8FB9F735-D64C-4991-8D91-4CDDAB1ABDEE}, "Autodesk Material Library 2017"

::::== Autodesk Material Library Base Resolution Image Library 2017
call :funcUninstall {3FBFBC43-9882-43FA-B979-2D53896747B3}, "Autodesk Material Library Base Resolution Image Library 2017"

::::== Autodesk License Service (x64) - 3.1
call :funcUninstall {EB6FE58F-8576-4272-BB9C-6B47D9EDFA4D}, "Autodesk License Service (x64) - 3.1"

::::== Autodesk Material Library Low Resolution Image Library 2017
call :funcUninstall {360AC116-6CD4-4E7D-8174-28D47B05E898}, "Autodesk Material Library Low Resolution Image Library 2017"

::::== Autodesk Design Review 2013
call :funcUninstall {153DB567-6FF3-49AD-AC4F-86F8A3CCFDFB}, "Autodesk Design Review 2013"

::::== Autodesk Inventor 2017
call :funcUninstall {7F4DD591-2164-0001-0000-7107D70F3DB4}, "Autodesk Inventor 2017"

::::== Eco Materials Adviser for Autodesk Inventor 2017 (64-bit)
::::Manual uninstallation only

::::== Microsoft Visual C++ 2008 SP1 Redistributable (x64)
::::Manual uninstallation only

::::== DirectX Runtime
::::Manual uninstallation only

::::== Microsoft Access database engine 2010 (English)
::::Manual uninstallation only

::::== Microsoft Visual C++ 2008 x86 ATL Runtime 9.0.30729
::::Manual uninstallation only

::::== Microsoft Visual C++ 2008 x86 MFC Runtime 9.0.30729
::::Manual uninstallation only

::::== Microsoft Visual C++ 2008 x86 CRT Runtime 9.0.30729
::::Manual uninstallation only

::::== Microsoft Visual C++ 2008 x86 OpenMP Runtime 9.0.30729
::::Manual uninstallation only

::::== Microsoft Visual C++ 2008 x64 ATL Runtime 9.0.30729
::::Manual uninstallation only

::::== Microsoft Visual C++ 2008 x64 MFC Runtime 9.0.30729
::::Manual uninstallation only

::::== Microsoft Visual C++ 2008 x64 CRT Runtime 9.0.30729
::::Manual uninstallation only

::::== Microsoft Visual C++ 2008 x64 OpenMP Runtime 9.0.30729
::::Manual uninstallation only

::::== FARO LS 1.1.505.0 (64bit)
::::Manual uninstallation only

::::== Autodesk Inventor 2017 English Language Pack
call :funcUninstall {7F4DD591-2164-0001-1033-7107D70F3DB4}, "Autodesk Inventor 2017 English Language Pack"

::::== Autodesk Desktop Connect Service
call :funcUninstall {FC772454-BB19-0000-0330-44B459520227}, "Autodesk Desktop Connect Service"

::::== Autodesk Guided Tutorial Plugin
call :funcUninstall {B3AFC608-D811-0003-0330-21FB25B48D6E}, "Autodesk Guided Tutorial Plugin"

::::== Inventor Connected Desktop for A360
call :funcUninstall {1FA52755-1FBC-0001-0330-7CEA1F3736D8}, "Inventor Connected Desktop for A360"

::::== Autodesk Configurator 360 addin
call :funcUninstall {E3EE083F-6856-44AB-BC82-445E2FFB8C1A}, "Autodesk Configurator 360 addin"

::::== DWG TrueView 2017 - English
call :funcUninstall {28B89EEF-0028-0409-0100-CF3F3A09B77D}, "DWG TrueView 2017 - English"

::::== Autodesk Inventor Electrical Catalog Browser 2017 - English
call :funcUninstall {28B89EEF-0007-0000-7102-CF3F3A09B77D}, "Autodesk Inventor Electrical Catalog Browser 2017 - English"

::::== Autodesk Inventor Electrical Catalog Browser 2017 Language Pack - English
call :funcUninstall {28B89EEF-0007-0409-8102-CF3F3A09B77D}, "Autodesk Inventor Electrical Catalog Browser 2017 Language Pack - English"

::::== Autodesk Revit Interoperability for Inventor 2017
call :funcUninstall {0BB716E0-1700-0210-0000-097DC2F354DF}, "Autodesk Revit Interoperability for Inventor 2017"

::::== A360 Desktop
call :funcUninstall {7758802D-9486-4883-9927-CCAC366A3BA4}, "A360 Desktop"

::::== Autodesk® Inventor® Content Libraries
call :funcUninstall {05D87862-35C9-4CB4-92EC-8A1FC97BFF6C}, "Eco Materials Adviser for Autodesk Inventor 2017 (64-bit)"
call :funcUninstall {B46DECD1-2164-4EF1-0000-22D71E81877C}, "Autodesk Inventor Content Center Libraries 2017 (Desktop Content)"

::::== Uninstalling all previous ReCap/ReCap 360 installations
::::Manual uninstallation only

::::== Autodesk ReCap 360
call :funcUninstall {5F0F7049-0000-1033-0102-73A6DA3D7FA6}, "Autodesk ReCap 360"

::::== Autodesk Vault Basic 2017 (Client)
call :funcUninstall {CF526A26-2264-0000-0000-02E95019B628}, "Autodesk Vault Basic 2017 (Client)"

::::== Autodesk Vault Basic 2017 (Client) English Language Pack
call :funcUninstall {266597A9-2264-0000-0100-DCBF2B69166B}, "Autodesk Vault Basic 2017 (Client) English Language Pack"

::::== Autodesk Desktop App


::::== FARO Uninstall
call :funcUninstall {8834451B-6209-4E02-9EF4-4EF9E3C1F70F}, "FARO LS 1.1.505.0 (64bit)"
