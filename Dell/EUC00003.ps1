# Dell & Windows Update Assistant
# A modern UI tool to check for and install various system updates

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# Function to check if running as admin
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

# If not running as admin, restart with admin rights
if (-not (Test-Admin)) {
    $arguments = "& '" + $MyInvocation.MyCommand.Path + "'"
    Start-Process powershell -Verb RunAs -ArgumentList $arguments
    exit
}

# Function to get system information
function Get-SystemInfo {
    $computerSystem = Get-CimInstance CIM_ComputerSystem
    $operatingSystem = Get-CimInstance CIM_OperatingSystem
    $bios = Get-CimInstance CIM_BIOSElement
    
    $manufacturer = $computerSystem.Manufacturer
    $model = $computerSystem.Model
    $osName = $operatingSystem.Caption
    $osVersion = $operatingSystem.Version
    $biosVersion = $bios.SMBIOSBIOSVersion
    $lastBootUpTime = $operatingSystem.LastBootUpTime
    $uptime = (Get-Date) - $lastBootUpTime
    $uptimeString = "{0} days, {1} hours, {2} minutes" -f $uptime.Days, $uptime.Hours, $uptime.Minutes
    
    return @{
        Manufacturer = $manufacturer
        Model = $model
        OSName = $osName
        OSVersion = $osVersion
        BIOSVersion = $biosVersion
        LastBootUpTime = $lastBootUpTime.ToString("yyyy-MM-dd HH:mm:ss")
        Uptime = $uptimeString
    }
}

# Create UI
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Update Assistant" Height="600" Width="700" WindowStartupLocation="CenterScreen">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#0078D7"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Margin" Value="5"/>
            <Setter Property="Padding" Value="10,5"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Height" Value="35"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="4" BorderThickness="{TemplateBinding BorderThickness}" BorderBrush="{TemplateBinding BorderBrush}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#006CC1"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Text="System Update Assistant" FontSize="24" FontWeight="SemiBold" Margin="0,0,0,15"/>
        
        <!-- System Information Panel -->
        <Border Grid.Row="1" BorderBrush="#E5E5E5" BorderThickness="1" CornerRadius="4" Background="#F0F8FF" Margin="0,0,0,15">
            <Grid Margin="10">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                
                <TextBlock Grid.Column="0" Grid.Row="0" Grid.ColumnSpan="2" Text="System Information" FontWeight="Bold" FontSize="16" Margin="0,0,0,5"/>
                
                <StackPanel Grid.Column="0" Grid.Row="1">
                    <TextBlock><Run FontWeight="SemiBold">Manufacturer:</Run> <Run x:Name="ManufacturerText">Loading...</Run></TextBlock>
                    <TextBlock><Run FontWeight="SemiBold">Model:</Run> <Run x:Name="ModelText">Loading...</Run></TextBlock>
                </StackPanel>
                
                <StackPanel Grid.Column="1" Grid.Row="1">
                    <TextBlock><Run FontWeight="SemiBold">OS:</Run> <Run x:Name="OSText">Loading...</Run></TextBlock>
                    <TextBlock><Run FontWeight="SemiBold">Version:</Run> <Run x:Name="VersionText">Loading...</Run></TextBlock>
                </StackPanel>
                
                <StackPanel Grid.Column="0" Grid.Row="2" Margin="0,10,0,0">
                    <TextBlock><Run FontWeight="SemiBold">BIOS Version:</Run> <Run x:Name="BiosText">Loading...</Run></TextBlock>
                </StackPanel>
                
                <StackPanel Grid.Column="1" Grid.Row="2" Margin="0,10,0,0">
                    <TextBlock><Run FontWeight="SemiBold">Last Boot:</Run> <Run x:Name="LastBootText">Loading...</Run></TextBlock>
                    <TextBlock><Run FontWeight="SemiBold">Uptime:</Run> <Run x:Name="UptimeText">Loading...</Run></TextBlock>
                </StackPanel>
                
                <Button x:Name="RefreshInfoBtn" Grid.Column="0" Grid.Row="3" Grid.ColumnSpan="2" Content="Refresh System Info" HorizontalAlignment="Right" Width="150" Height="30" Margin="0,10,0,0"/>
            </Grid>
        </Border>

        <Border Grid.Row="2" BorderBrush="#E5E5E5" BorderThickness="1" CornerRadius="4" Background="#F9F9F9">
            <ScrollViewer Margin="5" VerticalScrollBarVisibility="Auto">
                <TextBox x:Name="OutputBox" IsReadOnly="True" TextWrapping="Wrap" FontFamily="Consolas" 
                         Background="Transparent" BorderThickness="0" Margin="5"/>
            </ScrollViewer>
        </Border>

        <Grid Grid.Row="3" Margin="0,15,0,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <Button x:Name="DellUpdateBtn" Grid.Column="0" Content="Dell Updates" />
            <Button x:Name="WindowsUpdateBtn" Grid.Column="1" Content="Windows Updates" />
            <Button x:Name="OfficeUpdateBtn" Grid.Column="2" Content="Office Updates" />
            <Button x:Name="WingetUpdateBtn" Grid.Column="3" Content="App Updates" />
        </Grid>
    </Grid>
</Window>
"@

# Load XAML
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get UI elements
$outputBox = $window.FindName("OutputBox")
$dellUpdateBtn = $window.FindName("DellUpdateBtn")
$windowsUpdateBtn = $window.FindName("WindowsUpdateBtn")
$officeUpdateBtn = $window.FindName("OfficeUpdateBtn")
$wingetUpdateBtn = $window.FindName("WingetUpdateBtn")
$refreshInfoBtn = $window.FindName("RefreshInfoBtn")

# Get system info UI elements
$manufacturerText = $window.FindName("ManufacturerText")
$modelText = $window.FindName("ModelText")
$osText = $window.FindName("OSText")
$versionText = $window.FindName("VersionText")
$biosText = $window.FindName("BiosText")
$lastBootText = $window.FindName("LastBootText")
$uptimeText = $window.FindName("UptimeText")

# Function to update system information
function Update-SystemInfoPanel {
    $sysInfo = Get-SystemInfo
    
    $manufacturerText.Text = $sysInfo.Manufacturer
    $modelText.Text = $sysInfo.Model
    $osText.Text = $sysInfo.OSName
    $versionText.Text = $sysInfo.OSVersion
    $biosText.Text = $sysInfo.BIOSVersion
    $lastBootText.Text = $sysInfo.LastBootUpTime
    $uptimeText.Text = $sysInfo.Uptime
    
    Add-Log "System information refreshed."
}

# Function to add text to the output box
function Add-Log {
    param([string]$text)
    
    $timestamp = Get-Date -Format "[yyyy-MM-dd HH:mm:ss]"
    $outputBox.AppendText("$timestamp $text`r`n")
    $outputBox.ScrollToEnd()
}

# Function to get latest Dell Command Update
function Install-DellCommandUpdate {
    param(
        [switch]$Force,
        [ValidateSet("Universal", "Windows", "Auto")]
        [string]$Variant = "Auto"
    )

    Add-Log "Starting Dell Command Update download process..."
    
    # Registry paths to check for installed applications
    $RegPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    # Determine which variant to look for
    $universalAppName = 'Dell Command | Update for Windows Universal'
    $windowsAppName = 'Dell Command | Update'
    
    if ($Variant -eq "Auto") {
        # Check if any variant is already installed
        $installedApp = Get-ChildItem -Path $RegPaths | 
            Get-ItemProperty | 
            Where-Object { 
                $_.DisplayName -like "*Dell Command*Update*" 
            } | 
            Sort-Object -Property DisplayVersion -Descending | 
            Select-Object -First 1
        
        if ($installedApp) {
            Add-Log "Found existing Dell Command Update: $($installedApp.DisplayName) - $($installedApp.DisplayVersion)"
            
            # Use the same variant that's already installed unless forced
            if ($installedApp.DisplayName -like "*Universal*") {
                $appName = $universalAppName
                $variant = "Universal"
            } else {
                $appName = $windowsAppName
                $variant = "Windows"
            }
            
            if (-not $Force) {
                Add-Log "Using existing variant: $variant - if you want to change it, use -Force parameter"
                return $installedApp
            }
        } else {
            # Default to Universal if nothing installed
            $appName = $universalAppName
            $variant = "Universal"
        }
    } else {
        # Use specified variant
        $appName = if ($Variant -eq "Universal") { $universalAppName } else { $windowsAppName }
    }
    
    Add-Log "Checking for $variant version of Dell Command Update..."
    
    # Get current installed version
    $currentApp = Get-ChildItem -Path $RegPaths | 
        Get-ItemProperty | 
        Where-Object { $_.DisplayName -like $appName } | 
        Select-Object -First 1
    
    # Get latest version available from Dell's site
    try {
        Add-Log "Retrieving download information from Dell website..."
        
        # Dell KB article with download link
        $DellURL = 'https://www.dell.com/support/kbdoc/en-uk/000177325/dell-command-update'
        $Headers = @{
            'accept'          = 'text/html'
            'accept-encoding' = 'gzip, deflate'
            'accept-language' = '*'
            'user-agent'      = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }

        [String]$DellWebPage = Invoke-RestMethod -UseBasicParsing -Uri $DellURL -Headers $Headers
        $DownloadURL = $null
        
        # Extract the appropriate download URL based on variant
        if ($Variant -eq "Universal") {
            if ($DellWebPage -match '(https://dl\.dell\.com.+?Dell-Command-Update-Windows-Universal.+?\.exe)') { 
                $DownloadURL = $Matches[1]
                Add-Log "Found Universal download URL: $DownloadURL" 
            }
        } else { # Windows variant
            if ($DellWebPage -match '(https://dl\.dell\.com.+?Dell-Command-Update-Application.+?\.exe)') { 
                $DownloadURL = $Matches[1]
                Add-Log "Found Windows Application download URL: $DownloadURL" 
            }
        }

        if (-not $DownloadURL) {
            # Fallback to any Dell Command Update executable
            if ($DellWebPage -match '(https://dl\.dell\.com.+?Dell-Command-Update.+?\.exe)') { 
                $DownloadURL = $Matches[1]
                Add-Log "Found fallback download URL: $DownloadURL"
            } else {
                Add-Log "Error: Could not find any Dell Command Update download link" -ForegroundColor Red
                return $false
            }
        }

        # Extract version from URL or filename
        $Version = $DownloadURL | 
            Select-String -Pattern '(\d+\.\d+\.\d+)' | 
            ForEach-Object { $_.Matches.Groups[1].Value }

        if (-not $Version) {
            $Version = "Unknown"
        }

        Add-Log "Latest Dell Command Update version: $Version"
        
        # Check if we need to update
        if ($currentApp -and ($currentApp.DisplayVersion -eq $Version) -and (-not $Force)) {
            Add-Log "Already have the latest version ($Version). No update needed."
            return $currentApp
        }
        
        # Download the installer
        $Installer = "$env:TEMP\DCU_$($Variant)_$($Version).exe"
        Add-Log "Downloading Dell Command Update to $Installer..."
        
        # Download with progress display
        $ProgressPreference = 'Continue'
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
        
        # Register the event to track download progress
        $downloadComplete = $false
        $evt = Register-ObjectEvent -InputObject $wc -EventName DownloadProgressChanged -Action {
            $progress = $EventArgs.ProgressPercentage
            Write-Progress -Activity "Downloading Dell Command Update" -Status "$progress% Complete" -PercentComplete $progress
            if ($progress -eq 100) { $downloadComplete = $true }
        }
        
        try {
            # Start download
            $wc.DownloadFileAsync($DownloadURL, $Installer)
            
            # Wait for download to complete
            while (-not $downloadComplete) {
                Start-Sleep -Milliseconds 100
            }
            
            # Clean up event handler
            Unregister-Event -SourceIdentifier $evt.Name
            
            Write-Progress -Activity "Downloading Dell Command Update" -Completed
            Add-Log "Download complete"
        } catch {
            Unregister-Event -SourceIdentifier $evt.Name -ErrorAction SilentlyContinue
            Add-Log "Error during download: $($_.Exception.Message)"
            return $false
        }
        
        # Install the application
        Add-Log "Installing Dell Command Update $Version..."
        try {
            Start-Process -FilePath $Installer -ArgumentList "/S" -Wait
            Add-Log "Installation completed successfully"
            
            # Verify installation
            Start-Sleep -Seconds 3  # Give it a moment to finalize
            $updatedApp = Get-ChildItem -Path $RegPaths | 
                Get-ItemProperty | 
                Where-Object { $_.DisplayName -like "*Dell Command*Update*" } | 
                Sort-Object -Property DisplayVersion -Descending | 
                Select-Object -First 1
                
            if ($updatedApp) {
                Add-Log "Verified installation: $($updatedApp.DisplayName) - $($updatedApp.DisplayVersion)"
                return $updatedApp
            } else {
                Add-Log "Installation verification failed. Please check manually."
                return $false
            }
        }
        catch {
            Add-Log "Error during installation: $($_.Exception.Message)"
            return $false
        }
    }
    catch {
        Add-Log "Error retrieving Dell Command Update information: $($_.Exception.Message)"
        return $false
    }
}

# Function to run Dell Command Update
function Start-DellUpdate {
    if (Install-DellCommandUpdate) {
        Add-Log "Running Dell Command Update scan..."
        
        # Check if the CLI version is installed
        $dcuCliPath = "C:\Program Files\Dell\CommandUpdate\dcu-cli.exe"
        $dcuAppPath = "C:\Program Files\Dell\CommandUpdate\DellCommandUpdate.exe"
        
        if (Test-Path $dcuCliPath) {
            # Use CLI version
            Add-Log "Using Dell Command Update CLI..."
            $scanResults = & $dcuCliPath /scan -outputLog="$env:TEMP\dcu_scan.log"
            Add-Log $scanResults
            
            Add-Log "Checking for available updates..."
            $scanResults = & $dcuCliPath /applyUpdates -reboot=disable -outputLog="$env:TEMP\dcu_apply.log"
            Add-Log $scanResults
        }
        elseif (Test-Path $dcuAppPath) {
            # Launch the GUI if CLI is not available
            Add-Log "Launching Dell Command Update application..."
            Start-Process $dcuAppPath
        }
        else {
            Add-Log "Error: Dell Command Update executable not found at expected location. Please run it manually."
        }
    }
}

# Function to check for Windows Updates
function Start-WindowsUpdate {
    Add-Log "Checking for Windows Updates..."
    
    try {
        # Check if PSWindowsUpdate module is installed
        if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Add-Log "Installing PSWindowsUpdate module..."
            Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser
            Import-Module PSWindowsUpdate
        }
        
        Add-Log "Scanning for Windows Updates..."
        $updates = Get-WindowsUpdate -MicrosoftUpdate
        
        if ($updates.Count -eq 0) {
            Add-Log "No Windows Updates available."
        } else {
            Add-Log "Found $($updates.Count) Windows Updates available:"
            foreach ($update in $updates) {
                Add-Log "- $($update.Title)"
            }
            
            $response = [System.Windows.MessageBox]::Show("Install $($updates.Count) Windows Updates?", "Windows Updates", [System.Windows.MessageBoxButton]::YesNo)
            if ($response -eq [System.Windows.MessageBoxResult]::Yes) {
                Add-Log "Installing Windows Updates..."
                Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -AutoReboot:$false | ForEach-Object {
                    Add-Log "- Installing: $($_.Title)"
                }
                Add-Log "Windows Update installation completed."
            } else {
                Add-Log "Windows Update installation cancelled."
            }
        }
    }
    catch {
        Add-Log "Error checking for Windows Updates: $_"
    }
}

# Function to check for Office Updates
function Start-OfficeUpdate {
    Add-Log "Checking for Microsoft Office Updates..."
    
    try {
        # Check if Office is installed
        $officePath = "C:\Program Files\Microsoft Office"
        $office365Path = "C:\Program Files\Microsoft Office 15"
        
        if ((Test-Path $officePath) -or (Test-Path $office365Path)) {
            Add-Log "Microsoft Office detected, checking for updates..."
            
            # Start Office update process via click-to-run
            $clickToRunPath = "C:\Program Files\Common Files\microsoft shared\ClickToRun\OfficeC2RClient.exe"
            
            if (Test-Path $clickToRunPath) {
                Add-Log "Updating Office via Click-to-Run..."
                Start-Process $clickToRunPath -ArgumentList "/update user" -Wait
                Add-Log "Office update process initiated."
            } else {
                # Try alternative method
                Add-Log "Using Microsoft Update service to check for Office updates..."
                
                if (Get-Module -ListAvailable -Name PSWindowsUpdate) {
                    Import-Module PSWindowsUpdate
                    $officeUpdates = Get-WindowsUpdate -MicrosoftUpdate | Where-Object { $_.Title -like "*Office*" }
                    
                    if ($officeUpdates.Count -gt 0) {
                        Add-Log "Found $($officeUpdates.Count) Office updates available:"
                        foreach ($update in $officeUpdates) {
                            Add-Log "- $($update.Title)"
                        }
                        
                        $response = [System.Windows.MessageBox]::Show("Install $($officeUpdates.Count) Office Updates?", "Office Updates", [System.Windows.MessageBoxButton]::YesNo)
                        if ($response -eq [System.Windows.MessageBoxResult]::Yes) {
                            Add-Log "Installing Office Updates..."
                            $officeUpdates | Install-WindowsUpdate -AcceptAll -AutoReboot:$false
                            Add-Log "Office Update installation completed."
                        } else {
                            Add-Log "Office Update installation cancelled."
                        }
                    } else {
                        Add-Log "No Office Updates available."
                    }
                } else {
                    Add-Log "PSWindowsUpdate module not available for Office updates."
                }
            }
        } else {
            Add-Log "Microsoft Office installation not detected."
        }
    }
    catch {
        Add-Log "Error checking for Office Updates: $_"
    }
}

# Function to check for App Updates using winget
function Start-WingetUpdate {
    Add-Log "Checking for app updates using winget..."
    
    try {
        # Check if winget is available
        $winget = Get-Command winget -ErrorAction SilentlyContinue
        
        if ($winget) {
            Add-Log "Scanning for application updates..."
            $updates = Invoke-Expression "winget upgrade" | Out-String
            Add-Log $updates
            
            $response = [System.Windows.MessageBox]::Show("Would you like to upgrade all applications?", "App Updates", [System.Windows.MessageBoxButton]::YesNo)
            if ($response -eq [System.Windows.MessageBoxResult]::Yes) {
                Add-Log "Installing all available application updates..."
                $upgradeOutput = Invoke-Expression "winget upgrade --all" | Out-String
                Add-Log $upgradeOutput
                Add-Log "Application updates completed."
            } else {
                Add-Log "Application updates cancelled."
            }
        } else {
            Add-Log "Winget is not installed. Installing App Installer..."
            
            # Try to install winget via Microsoft Store
            try {
                Start-Process "ms-windows-store://pdp/?ProductId=9NBLGGH4NNS1"
                Add-Log "Microsoft Store opened. Please install App Installer (winget) and then try again."
            }
            catch {
                Add-Log "Unable to open Microsoft Store. Please install winget manually."
            }
        }
    }
    catch {
        Add-Log "Error checking for app updates: $_"
    }
}

# Button click handlers
$dellUpdateBtn.Add_Click({
    # First check if this is a Dell system
    if ($manufacturerText.Text -notlike "*Dell*") {
        $response = [System.Windows.MessageBox]::Show(
            "This computer does not appear to be a Dell system. Dell Command Update is designed for Dell systems only. Do you want to continue anyway?", 
            "Non-Dell System Detected", 
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning
        )
        if ($response -ne [System.Windows.MessageBoxResult]::Yes) {
            Add-Log "Dell Command Update installation cancelled - non-Dell system"
            return
        }
    }
    
    $dellUpdateBtn.IsEnabled = $false
    $dellUpdateBtn.Content = "Working..."
    
    try {
        # Get latest DCU
        $dcuResult = Install-DellCommandUpdate -Variant Auto
        
        if ($dcuResult) {
            # Now run Dell Command Update
            Start-DellUpdate
        }
    }
    finally {
        $dellUpdateBtn.IsEnabled = $true
        $dellUpdateBtn.Content = "Dell Updates"
    }
})

$windowsUpdateBtn.Add_Click({
    Start-WindowsUpdate
})

$officeUpdateBtn.Add_Click({
    Start-OfficeUpdate
})

$wingetUpdateBtn.Add_Click({
    Start-WingetUpdate
})

$refreshInfoBtn.Add_Click({
    Update-SystemInfoPanel
})

# Initial log
Add-Log "Update Assistant initialized. Running as Administrator: $(Test-Admin)"
Add-Log "Ready to perform system and application updates."
Add-Log "Select an update action from the buttons below."

# Initialize system information panel
Update-SystemInfoPanel

# Show the window
$window.ShowDialog() | Out-Null