# Set Variables
$FolderPaths = @("C:\OSDCloud\","C:\Drivers\")
# $FilePaths = @("$Env:SystemDrive\Temp\Test.txt","$Env:SystemDrive\Test\path1\Path2\test.txt")

# Check if folders exist then delete them.
If ($FolderPaths){
    Try {
        ForEach ($FolderPath in $FolderPaths) {
            $FolderTest = Test-Path $FolderPath

            # Get the parent and the leaf from each path
            $FolderParent = Split-Path $FolderPath -Parent
            $FolderLeaf = Split-Path $FolderPath -Leaf

            If (!($FolderTest)){
                Remove-item -Path $FolderParent -Name $FolderLeaf -Force -ItemType Directory
                Write-Host "Folder $FolderPath removed successfully."
            }
            Else {
                Write-Host "Folder $FolderPath already deleted."
            }
        }
        Write-Host "All folders deleted successfully."
    }
    Catch {
        $ErrorMsg = $_.Exception.Message
        Write-host "Error $ErrorMsg"
        Exit 1
    }
}