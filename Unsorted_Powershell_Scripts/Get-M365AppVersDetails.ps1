# Output Office 365 update channel and version

# identifiers for the channels
#
# Current Channel (formerly Monthly Channel):
# CDNBaseUrl = http://officecdn.microsoft.com/pr/492350f6-3a01-4f97-b9c0-c7c6ddf67d60
#
# Current Channel (preview) (formerly Monthly Channel (Targeted) ):
# CDNBaseUrl = http://officecdn.microsoft.com/pr/64256afe-f5d9-4f86-8936-8840a6a4f5be
#
# Semi-Annual Enterprise Channel (formerly semi-annual channel)
# CDNBaseUrl = http://officecdn.microsoft.com/pr/7ffbc6bf-bc32-4f92-8982-f9dd17fd3114
#
# Semi-Annual Enterprise Channel (Preview) (formerly Semi-annual channel (targeted)):
# CDNBaseUrl = http://officecdn.microsoft.com/pr/b8f9b850-328d-4355-9145-c59439a0c4cf
#
# Monthly Enterprise Channel
# CDNBaseUrl = http://officecdn.microsoft.com/pr/55336b82-a18d-4dd6-b5f6-9e5095c314a6
#
# Beta (formerly Insider)
# CDNBaseUrl = http://officecdn.microsoft.com/pr/5440fd1f-7ecb-4221-8110-145efaa6372f

$channelids = @{
    'CurrentChannel'                        = "http://officecdn.microsoft.com/pr/492350f6-3a01-4f97-b9c0-c7c6ddf67d60"
    'CurrentChannel(Preview)'               = "http://officecdn.microsoft.com/pr/64256afe-f5d9-4f86-8936-8840a6a4f5be"
    'Semi-AnnualEnterpriseChannel'          = "http://officecdn.microsoft.com/pr/7ffbc6bf-bc32-4f92-8982-f9dd17fd3114"
    'Semi-AnnualEnterpriseChannel(Preview)' = "http://officecdn.microsoft.com/pr/b8f9b850-328d-4355-9145-c59439a0c4cf"
    'MonthlyEnterpriseChannel'              = "http://officecdn.microsoft.com/pr/55336b82-a18d-4dd6-b5f6-9e5095c314a6"
    'Beta'                                  = "http://officecdn.microsoft.com/pr/5440fd1f-7ecb-4221-8110-145efaa6372f"
}

# office config registry key
$configuration = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration' 

$updateChannelURL = $configuration.CDNBaseUrl

$channelname = "not found in list"
foreach ($key in $channelids.keys) {
    if ($channelids[$key] -eq $updateChannelURL) {
        $channelname = $key
        break
    }
}

$displayVersion = $null
if ( [System.Version]::TryParse($configuration.VersionToReport, $([ref]$displayVersion))) {
    Write-Output ("Discovered VersionToReport {0}" -f $displayVersion.ToString())
} else {
    $displayVersion = "unable to parse"
}

Write-Output ("Channel name: {0}; Version {1}" -f $channelname,$displayVersion)


Exit 0

