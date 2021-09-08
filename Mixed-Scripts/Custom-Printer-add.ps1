pnputil.exe /a "\\fileshare\HPPrinter\*.inf"
Add-PrinterDriver -Name "HP OfficeJet 5200 series PCL-3" -InfPath "C:\Windows\System32\DriverStore\FileRepository\hpygid24_v4.inf_amd64_f312bf16a5228084\hpygid24_v4.inf"
Add-PrinterPort -Name "Ports McGee" -PrinterHostAddress "IP Of Printer"
Add-Printer -DriverName "HP OfficeJet 5200 series PCL-3" -Name "Printy" -PortName "Ports McGee"