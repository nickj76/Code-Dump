<# 
.SYNOPSIS
   Install AzInfoProtection_2.10.46_CoAuthoring_PublicPreview

.DESCRIPTION
   Installs the AzInfoProtection_2.10.46_CoAuthoring_PublicPreview checks to see if the logfiles directory exists if it does not it creates it.

.EXAMPLE
   PS C:\> .\AzInfoProtection_2.10.46_CoAuthoring_PublicPreview.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.NOTES
   None.

.FUNCTIONALITY
   PowerShell v3+
#>

&.\AzInfoProtection_2.10.46_CoAuthoring_PublicPreview.exe /S | Out-Null

$path = "C:\logfiles"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

New-Item -ItemType "file" -Path "c:\logfiles\AzInfoProtection_2.10.46_CoAuthoring_PublicPreview.txt"
