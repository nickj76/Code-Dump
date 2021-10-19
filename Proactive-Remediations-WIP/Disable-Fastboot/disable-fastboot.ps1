<#
.SYNOPSIS
  Disable FastBoot
.DESCRIPTION
  Disables FastBoot via registry
  Device Context 32-bit
  
.EXAMPLE
N/A
#>

#-----------------------------------------------------------[Execution]------------------------------------------------------------

if((Test-Path -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power") -ne $true) {  New-Item "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -force -ea SilentlyContinue };
New-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name 'HiberbootEnabled' -Value 0 -PropertyType DWord -Force -ea SilentlyContinue;
