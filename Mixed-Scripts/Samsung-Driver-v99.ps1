If ($ENV:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    Try {
        &"$ENV:WINDIR\SysNative\WindowsPowershell\v1.0\PowerShell.exe" -File $PSCOMMANDPATH
    }
    Catch {
        Throw "Failed to start $PSCOMMANDPATH"
    }
    Exit
}

Start-Transcript -Path c:\temp\SamsungDriver.txt

&"C:\Program Files\7-Zip\7z.exe" x -oc:\temp\ -y *.7z

Get-ChildItem "C:\temp\printer" -Recurse -Filter "*.inf" | 
ForEach-Object { PNPUtil.exe /add-driver $_.FullName /install }

add-printerdriver -name 'Samsung Universal Print Driver 2 PCL6'

# Create Detection Method.
$path = "C:\logfiles"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

New-Item -ItemType "file" -Path "c:\logfiles\SamsungPrintUniDriver.txt"
Stop-Transcript


















