
## Clear Browser Caches

#------------------------------------------------------------------#
#- Stop-BrowserSessions                                            #
#------------------------------------------------------------------#
Function Stop-BrowserSessions {
   $activeBrowsers = Get-Process Firefox*,Chrome*,Waterfox*,Edge*
   ForEach($browserProcess in $activeBrowsers)
   {
       try 
       {
           $browserProcess.CloseMainWindow() | Out-Null 
       } catch { }
   }
}

#------------------------------------------------------------------#
#- Get-StorageSize                                                 #
#------------------------------------------------------------------#
Function Get-StorageSize {
    Get-WmiObject Win32_LogicalDisk | 
    Where-Object { $_.DriveType -eq "3" } | 
    Select-Object SystemName, 
        @{ Name = "Drive" ; Expression = { ( $_.DeviceID ) } },
        @{ Name = "Size (GB)" ; Expression = {"{0:N1}" -f ( $_.Size / 1gb)}},
        @{ Name = "FreeSpace (GB)" ; Expression = {"{0:N1}" -f ( $_.Freespace / 1gb ) } },
        @{ Name = "PercentFree" ; Expression = {"{0:P1}" -f ( $_.FreeSpace / $_.Size ) } } |
    Format-Table -AutoSize | Out-String
}

#------------------------------------------------------------------#
#- Remove-Dir                                               #
#------------------------------------------------------------------#
Function Remove-Dir {
    param([Parameter(Mandatory=$true)][string]$path)

	if((Test-Path "$path"))
	{
		Get-ChildItem -Path "$path" -Force -ErrorAction SilentlyContinue | Get-ChildItem -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -Verbose
	}
}

#Region Browsers

#Region ChromiumBrowsers

#------------------------------------------------------------------#
#- Clear-ChromeTemplate                                            #
#------------------------------------------------------------------#
Function Clear-ChromeTemplate {
    param(
    	[Parameter(Mandatory=$true)][string]$path,
    	[Parameter(Mandatory=$true)][string]$name
	)

    if((Test-Path $path))
    {
    	Write-Output "Clear cache $name"
        $possibleCachePaths = @("Cache","Cache2\entries\","ChromeDWriteFontCache","Code Cache","GPUCache","JumpListIcons","JumpListIconsOld","Media Cache","Service Worker","Top Sites","VisitedLinks","Web Data")
        ForEach($cachePath in $possibleCachePaths)
        {
            Remove-Dir "$path\$cachePath"
        }
    }
}

#------------------------------------------------------------------#
#- Clear-MozillaTemplate                                           #
#------------------------------------------------------------------#
Function Clear-MozillaTemplate {
    param(
    	[Parameter(Mandatory=$true)][string]$path,
    	[Parameter(Mandatory=$true)][string]$name
	)

    if((Test-Path $path))
    {
    	Write-Output "Clear cache $name"
    	$AppDataPath = (Get-ChildItem "$path" | Where-Object { $_.Name -match "Default" }[0]).FullName
        $possibleCachePaths = @("cache","cache2\entries","thumbnails","webappsstore.sqlite","chromeappstore.sqlite")
        ForEach($cachePath in $possibleCachePaths)
        {
            Remove-Dir "$AppDataPath\$cachePath"
        }
    }
}


#------------------------------------------------------------------#
#- Clear-ChromeCache                                               #
#------------------------------------------------------------------#
Function Clear-ChromeCacheFiles {
    param([string]$user=$env:USERNAME)
    Clear-ChromeTemplate "C:\users\$user\AppData\Local\Google\Chrome\User Data\Default" "Browser Google Chrome"
    Remove-Dir "C:\users\$user\AppData\Local\Google\Chrome\User Data\SwReporter\"
}

#------------------------------------------------------------------#
#- Clear-EdgeCache                                                 #
#------------------------------------------------------------------#
Function Clear-EdgeCacheFiles {
    param([string]$user=$env:USERNAME)
    Clear-ChromeTemplate "C:\users\$user\AppData\Local\Microsoft\Edge\User Data\Default" "Browser Microsoft Edge"
}

#Endregion ChromiumBrowsers

#Region FirefoxBrowsers

#------------------------------------------------------------------#
#- Clear-FirefoxCacheFiles                                         #
#------------------------------------------------------------------#
Function Clear-FirefoxCacheFiles {
    param([string]$user=$env:USERNAME)
    Clear-MozillaTemplate "C:\users\$user\AppData\Local\Mozilla\Firefox\Profiles" "Browser Mozilla Firefox"
}

#------------------------------------------------------------------#
#- Clear-WaterfoxCacheFiles                                        #
#------------------------------------------------------------------#
Function Clear-WaterfoxCacheFiles { 
    param([string]$user=$env:USERNAME)
    Clear-MozillaTemplate "C:\users\$user\AppData\Local\Waterfox\Profiles" "Browser Waterfox"
}

#Endregion FirefoxBrowsers

#Endregion Browsers