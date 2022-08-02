$expected_checksum = "A7BBC4B4F781E04214ECEBE69A766C76681AA7EB"
$file_to_checksum = "c:\windows\notepad.exe"
#$Algorithm = "sha1" #must be sha1 or md5, default sha1

function Get-Checksum
{
    Param (
        [string]$File=$(throw("You must specify a filename to get the checksum of.")),
        [ValidateSet("sha1","md5")]
        [string]$Algorithm="sha1"
    )

    if ($File -match '^\.\\') { $File = (get-item $File).FullName }
    $fs = new-object System.IO.FileStream $File, "Open", "Read", "Read"
    $algo = [type]"System.Security.Cryptography.$Algorithm"
	$crypto = $algo::Create()
    $hash = [BitConverter]::ToString($crypto.ComputeHash($fs)).Replace("-", "")
    $fs.Close()
    $hash
}

if (test-path -PathType Leaf $file_to_checksum) { $current_checksum = get-checksum -file $file_to_checksum }

if ($expected_checksum -eq $current_checksum) { Write-Host "Installed" }