Invoke-HKCURegistrySettingsForAllUsers -RegistrySettings {Set-RegistryKey -Key 'HKEY_CURRENT_USER\Software\UNIT4\ReportEngine\Login\WebService\' -Name 'DataSource' -Value 'https://agresso.surrey.ac.uk/Unit4ERP-reportengine/service.asmx' -Type String -SID $UserProfile.SID}
Invoke-HKCURegistrySettingsForAllUsers -RegistrySettings {Set-RegistryKey -Key 'HKEY_CURRENT_USER\Software\UNIT4\ReportEngine\Login\WebService\' -Name 'DataSources' -Value 'https://agresso.surrey.ac.uk/Unit4ERP-reportengine/service.asmx' -Type String -SID $UserProfile.SID}
Invoke-HKCURegistrySettingsForAllUsers -RegistrySettings {Set-RegistryKey -Key 'HKEY_CURRENT_USER\Software\UNIT4\ReportEngine\Login\WebService\' -Name 'Authenticator' -Value 'AgressoAuthenticator' -Type String -SID $UserProfile.SID}

Invoke-HKCURegistrySettingsForAllUsers -RegistrySettings {Set-RegistryKey -Key 'HKEY_CURRENT_USER\Software\UNIT4\ReportEngine\Login\WebService\AgressoAuthenticator' -Name 'UserName' -Value '[System.Environment]::UserName' -Type String -SID $UserProfile.SID}
Invoke-HKCURegistrySettingsForAllUsers -RegistrySettings {Set-RegistryKey -Key 'HKEY_CURRENT_USER\Software\UNIT4\ReportEngine\Login\WebService\AgressoAuthenticator' -Name 'Client' -Value 'SY' -Type String -SID $UserProfile.SID}

