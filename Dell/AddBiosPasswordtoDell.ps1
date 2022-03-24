Install-PackageProvider -Name NuGet -Force

Install-Module VcRedist
Import-Module VcRedist
$VcList = Get-VcList | Get-VcRedist -Path "C:\Temp\VcRedist"
$VcList | Install-VcRedist -Path C:\Temp\VcRedist

Install-Module -Name DellBIOSProvider -Force
Import-Module -Name DellBIOSProvider

$x = "bDtja2Q0d24="
$z = [System.Text.Encoding]::Ascii.GetString([System.Convert]::FromBase64String($x));Set-Item -Path DellSmbios:\Security\AdminPassword $z

