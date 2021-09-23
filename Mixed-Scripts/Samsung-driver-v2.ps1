Get-ChildItem "C:\temp\printer" -Recurse -Filter "*.inf" | 
ForEach-Object { PNPUtil.exe /add-driver $_.FullName /install }

add-printerdriver -name 'Samsung Universal Print Driver 2 PCL6'