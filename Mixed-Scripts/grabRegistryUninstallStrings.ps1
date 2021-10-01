$ColRegUinst = @()
(Get-Item -Path 'HKLM:\software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall').GetSubKeyNames() |
%{
    if ( (Get-Item -Path "HKLM:\software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$_").GetValue("DisplayName") -ne $null)
    {
        $ObjRegUinst = New-Object System.Object
        $ObjRegUinst | Add-Member -Type NoteProperty -Name Publisher -Value (Get-Item -Path "HKLM:\software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$_").GetValue("Publisher")
        $ObjRegUinst | Add-Member -Type NoteProperty -Name Name -Value (Get-Item -Path "HKLM:\software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$_").GetValue("DisplayName")
        $ObjRegUinst | Add-Member -Type NoteProperty -Name Uninstall -Value (Get-Item -Path "HKLM:\software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$_").GetValue("UninstallString")
        $ColRegUinst += $ObjRegUinst
    }
}
$ColRegUinst | Out-GridView