$Picture1_Base64 = "place your base64 string that needs decoding here"
$BadgeImage = "$env:TEMP\badgePicture.png"
[byte[]]$Bytes = [convert]::FromBase64String($Picture1_Base64)
[System.IO.File]::WriteAllBytes($BadgeImage,$Bytes)