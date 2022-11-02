$SoftwareDistributionTask = @"
(Get-Service -Name wuauserv).WaitForStatus('Stopped', '01:00:00')
Get-ChildItem -Path `$env:SystemRoot\SoftwareDistribution\Download -Recurse -Force | Remove-Item -Recurse -Force

[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

[xml]`$ToastTemplate = @"""
<toast duration="""Long""">
	<visual>
		<binding template="""ToastGeneric""">
			<text>$($Localization.TaskNotificationTitle)</text>
			<group>
				<subgroup>
					<text hint-style="""body""" hint-wrap="""true""">$($Localization.SoftwareDistributionTaskNotificationEvent)</text>
				</subgroup>
			</group>
		</binding>
	</visual>
	<audio src="""ms-winsoundevent:notification.default""" />
    <actions>
		<input id="""SnoozeTimer""" type="""selection""" title="""$($Localization.SoftwareDistributionTaskNotificationEvent)""" defaultInput="""1""">
			<selection id="""1""" content="""$($Localization.Minute)""" />
			<selection id="""30""" content="""$($Localization.HalfHour)""" />
			<selection id="""240""" content="""$($Localization.FourHours)""" />
		</input>
		<action activationType="""system""" arguments="""snooze""" hint-inputId="""SnoozeTimer""" content="""""" id="""test-snooze"""/>
		<action arguments="""WindowsCleanup:""" content="""$($Localization.Run)""" activationType="""protocol"""/>
		<action arguments="""dismiss""" content="""""" activationType="""system"""/>
	</actions>
</toast>
"""@

`$ToastXml = [Windows.Data.Xml.Dom.XmlDocument]::New()
`$ToastXml.LoadXml(`$ToastTemplate.OuterXml)

`$ToastMessage = [Windows.UI.Notifications.ToastNotification]::New(`$ToastXML)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("""windows.immersivecontrolpanel_cw5n1h2txyewy!microsoft.windows.immersivecontrolpanel""").Show(`$ToastMessage)
"@

			# Create the "SoftwareDistribution" task
			$Action    = New-ScheduledTaskAction -Execute powershell.exe -Argument "-WindowStyle Hidden -Command $SoftwareDistributionTask"
			$Settings  = New-ScheduledTaskSettingsSet -Compatibility Win8 -StartWhenAvailable
			$Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest
			$Trigger   = New-ScheduledTaskTrigger -Daily -DaysInterval 90 -At 9pm
			$Parameters = @{
				TaskName    = "SoftwareDistribution"
				TaskPath    = "IT_Services"
				Action      = $Action
				Settings    = $Settings
				Principal   = $Principal
				Trigger     = $Trigger
				Description = "Delete the contents of %SystemRoot%\SoftwareDistribution\Download every 90 Days at "
			}
			Register-ScheduledTask @Parameters -Force
