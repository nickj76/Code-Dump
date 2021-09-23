&"C:\Program Files\7-Zip\7z.exe" x -oc:\temp\ -y *.7z

Get-ChildItem "C:\temp\printer" -Recurse -Filter "*.inf" | 
ForEach-Object { pnputil.exe -i -a $_.FullName }

add-printerdriver -name 'Samsung Universal Print Driver 2 PCL6'

# Create Detection Method.
$path = "C:\logfiles"
If(!(test-path $path))
{
      New-Item -ItemType Directory -Force -Path $path
}

New-Item -ItemType "file" -Path "c:\logfiles\SamsungPrintUniDriver.txt"