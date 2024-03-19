$text_file = "C:\NJ\AG\Bif.txt"
$bin_file = "C:\NJ\AG\AgrBIF9Setup.msi"

# binary -> text
[io.file]::WriteAllText($text_file, [Convert]::ToBase64String([io.file]::ReadAllBytes($bin_file)))