## Script to use powershell to uninstall MSI installed applications, by finding the GUID in the registry.

$product = Get-CIMinstance win32_product | `
Where-Object{$_.name -eq "Unit4 Batch Input Formatter 9"}
$product.IdentifyingNumber
msiexec /x $product.IdentifyingNumber /quiet /noreboot