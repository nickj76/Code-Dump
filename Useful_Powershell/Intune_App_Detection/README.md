# README for PSIntuneWinDetection PowerShell Script

## Overview
`PSIntuneWinDetection` is a PowerShell script designed to search and detect specific applications installed on a Windows system. It can check both 32-bit and 64-bit program installations, as well as software installed in user-specific contexts. The script is particularly useful for system administrators and IT professionals managing multiple Windows environments.

## Features
- **Application Detection:** Searches for a specific application based on its display name.
- **Version Specific Detection:** Can match a specific version of the application.
- **Architecture Aware:** Supports searching in both 64-bit and 32-bit registry paths.
- **User Context Aware:** Checks for installations in the user-specific context (`HKCU` registry hive).

## Prerequisites
- Windows PowerShell 5.1 or higher.
- Basic understanding of PowerShell scripting.

## Usage
1. **Set the Application Details:**
   Specify the application's display name and version you are looking for in the `$AppDisplayName` and `$AppDisplayVersion` variables, respectively.

   ```powershell
   $AppDisplayName = "your_app_name"
   $AppDisplayVersion = "your_app_version"
    ```
2. **Run the Script:**
    Execute the script with the desired parameters. Use the -Wow6432Node switch for 32-bit applications on a 64-bit system and the -userContext switch to include user-specific installations. The command will look like this: 
    ```powershell
    $appDetected = PSIntuneWinDetection -SearchFor $AppDisplayName -Wow6432Node -userContext | Where-Object { $_.DisplayVersion -eq $AppDisplayVersion }
    ```
3. **Check the Output:**
    The script will return **"installed"** if the specified application version is detected.
## Function Parameters
- **`-SearchFor`**: The display name of the application you are searching for.
- **`-Wow6432Node`**: (Optional) Include this switch to search in the 32-bit program registry path on a 64-bit system.
- **`-userContext`**: (Optional) Include this switch to search in the user-specific (`HKCU`) registry hive.

## Example
To search for a specific version of Visual Studio Code:

```powershell
$AppDisplayName = "Visual Studio Code"
$AppDisplayVersion = "1.55.0"

$appDetected = PSIntuneWinDetection -SearchFor $AppDisplayName -Wow6432Node -userContext | Where-Object { $_.DisplayVersion -eq $AppDisplayVersion }

if ($appDetected) {
    return "installed"
}
```
## Notes
- This script must be run with appropriate permissions to access the Windows registry.
- It's recommended to test the script in a controlled environment before deploying it in a production scenario.

## Contributing
Contributions to this script are welcome. Please ensure that your modifications are tested and documented.

## License
This script is provided 'as-is', without any express or implied warranty.

---
