Start-Process "https://www.ansys.com/en-gb/academic/students/ansys-student"

## Create Detection Method. 
$logfilespath = "C:\logfiles"
If(!(test-path $logfilespath))
{
      New-Item -ItemType Directory -Force -Path $logfilespath
}

New-Item -ItemType "file" -Path "c:\logfiles\Ansys-Student.txt"