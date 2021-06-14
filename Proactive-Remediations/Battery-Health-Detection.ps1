function CheckBatteryHealth {
	# Check for presence of battery and check where present
	If (Get-WmiObject win32_battery) {
		# Check machine type and other info
		[string]$SerialNumber = (Get-WmiObject win32_bios).SerialNumber
		
		# Maximum Acceptable Health Perentage
		$MinHealth = "40"

        # Multiple Battery handling
        $BatteryInstances = Get-WmiObject -Namespace "ROOT\WMI" -Class "BatteryStatus" | Select-Object -ExpandProperty InstanceName
		
        ForEach($BatteryInstance in $BatteryInstances){

            # Set Variables for health check

            $BatteryDesignSpec = Get-WmiObject -Namespace "ROOT\WMI" -Class "BatteryStaticData" | Where-Object -Property InstanceName -EQ $BatteryInstance | Select-Object -ExpandProperty DesignedCapacity
            $BatteryFullCharge = Get-WmiObject -Namespace "ROOT\WMI" -Class "BatteryFullChargedCapacity" | Where-Object -Property InstanceName -EQ $BatteryInstance | Select-Object -ExpandProperty FullChargedCapacity

            # Fall back WMI class for Microsoft Surface devices
            if ($BatteryDesignSpec -eq $null -or $BatteryFullCharge -eq $null -and ((Get-WmiObject -Class Win32_BIOS | Select-Object -ExpandProperty Manufacturer) -match "Microsoft")) {
	
                # Attempt to call WMI provider
	            if (Get-WmiObject -Class MSBatteryClass -Namespace "ROOT\WMI") {
		            $MSBatteryInfo = Get-WmiObject -Class MSBatteryClass -Namespace "root\wmi" | Where-Object -Property InstanceName -EQ $BatteryInstance | Select-Object FullChargedCapacity, DesignedCapacity
		
		            # Set Variables for health check
		            $BatteryDesignSpec = $MSBatteryInfo.DesignedCapacity
		            $BatteryFullCharge = $MSBatteryInfo.FullChargedCapacity
	            }
            }
		
		    if ($BatteryDesignSpec -gt $null -and $BatteryFullCharge -gt $null) {
			    # Determine battery replacement required
			    [int]$CurrentHealth = ($BatteryFullCharge/$BatteryDesignSpec) * 100
			    if ($CurrentHealth -le $MinHealth) {
				    $ReplaceBattery = $true
				
				    # Generate Battery Report
				    $ReportingPath = Join-Path -Path $env:SystemDrive -ChildPath "Reports"
				    if (-not (Test-Path -Path $ReportingPath)) {
					    New-Item -Path $ReportingPath -ItemType Dir | Out-Null
				    }
				    $ReportOutput = Join-Path -Path $ReportingPath -ChildPath $('\Battery-Report-' + $SerialNumber + '.html')
				
				    # Run Windows battery health report
				    Start-Process PowerCfg.exe -ArgumentList "/BatteryReport /OutPut $ReportOutput" -Wait -WindowStyle Hidden
				
				    # Output replacement message and flag for remediation step
				    Write-Output "Battery replacement required - $CurrentHealth% of manufacturer specifications"
				    exit 1
				
			    } else {
				    # Output replacement not required values
				    $ReplaceBattery = $false
				    Write-Output "Battery status healthy: $($CurrentHealth)% of manufacturer specifications"
				    # Not exiting here so that second battery can be checked
			    }
		    } else {
			# Output battery not present
			Write-Output "Battery not present in system."
			exit 0
		    }
            }
	    } else {
        # Output battery value condition check error
        Write-Output "Unable to obtain battery health information from WMI"
        exit 0
    }
}
CheckBatteryHealth