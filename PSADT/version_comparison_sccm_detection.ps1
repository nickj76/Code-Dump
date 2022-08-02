        $expected_version = [version]"4.6.2"

        If( (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full").Version -ge $expected_version) { Write-Host "Installed" } 