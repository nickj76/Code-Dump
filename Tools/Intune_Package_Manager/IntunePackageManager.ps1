<#!
.SYNOPSIS
  IntuneWin Package Manager - GUI tool to create, pull, decrypt, and extract Intune Win32 app packages.

.DESCRIPTION
    - Modern WPF GUI (card-based).
    - Async packaging (no UI freeze) using STA runspace + DispatcherTimer polling
    - Guard against concurrent actions
    - Live Message Center with level-based coloring (INFO/SUCCESS/WARNING/ERROR)
    - Validations: source folder, setup file must exist and be inside source, output path
    - Computes source folder size and shows package name
    - Default working root: %SystemDrive%\Intune\Installer and \Package
    - Includes .intunewin extraction (select package, choose destination, click Extract)
    - Extraction now supports nested metadata/payload discovery and improved diagnostics
    - Adds fallback ZIP boundary repair for decoded payloads when standard unzip fails
    - Can pull Win32 app content from Intune using Graph API and feed it into extraction workflow
    - Can pull Win32 app content using device MDM certificate flow (SideCar gateway)
    - Device certificate pull now performs GetContentInfo, package download, and decryption automatically
    - Extractor handles both standard IntuneWin wrappers and already-decoded ZIP payloads
    
.NOTES
    Author  : Nick Jenkins
    Date    : 2026-05-12
  Version : 3.5
#>

[CmdletBinding()]
param()

#region -------------------- Paths / constants --------------------
$SystemDrive = if ($env:SystemDrive) { $env:SystemDrive } else { 'C:' }
$ToolRoot = Join-Path $SystemDrive 'Intune'
$DefaultSourcePath = Join-Path $ToolRoot 'Installer'
$DefaultOutputPath = Join-Path $ToolRoot 'Package'

$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot }
elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath }
elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
else { (Get-Location).Path }

# If compiled with PS2EXE, embed like:
# -embedFiles @{ '%TEMP%\IntuneWinAppUtil.exe'='.\IntuneWinAppUtil.exe'; }
$tempRoot = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
$embeddedIntuneWinUtil = Join-Path $tempRoot 'IntuneWinAppUtil.exe'
$localIntuneWinUtil = Join-Path $ScriptDir 'IntuneWinAppUtil.exe'
$IntuneWinUtil = if (Test-Path $embeddedIntuneWinUtil) { $embeddedIntuneWinUtil } else { $localIntuneWinUtil }

$null = New-Item -ItemType Directory -Path $DefaultSourcePath, $DefaultOutputPath -Force -ErrorAction SilentlyContinue | Out-Null
$LogDir = $ToolRoot
$null = New-Item -ItemType Directory -Path $LogDir -Force -ErrorAction SilentlyContinue | Out-Null
$LogFile = Join-Path $LogDir ("IntunePackageManager-" + (Get-Date -Format "yyyyMMdd") + ".log")

# state
if ($script:clockTimer) { $script:clockTimer.Stop() }
if ($script:pollTimer) { $script:pollTimer.Stop() }

$script:IsBusy = $false
$script:ActiveRunspace = $null
$script:AsyncResult = $null
$script:AsyncPowerShell = $null
$script:LastProgress = 0
$script:SetupFilePath = $null
#endregion

#region -------------------- UI helpers / logging --------------------
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms | Out-Null

function New-Brush {
  param([string]$Hex = "#000000")
  $c = [Windows.Media.ColorConverter]::ConvertFromString($Hex)
  $b = New-Object Windows.Media.SolidColorBrush $c
  $b.Freeze(); $b
}

# UI log colors (match your Cisco style)
$BrushInfoUI    = New-Brush "#C7DAFF"
$BrushSuccessUI = New-Brush "#D7F0E3"
$BrushWarnUI    = New-Brush "#FBE6C5"
$BrushErrorUI   = New-Brush "#F7CFD2"

$BrushTextDark  = New-Brush "#1F2D3A"
$BrushTextOk    = New-Brush "#1F6A3A"
$BrushTextWarn  = New-Brush "#8A5A12"
$BrushTextBad   = New-Brush "#8A2026"

$script:LogSeen = New-Object 'System.Collections.Generic.HashSet[string]'
$script:LogWriter = $null
try { $script:LogWriter = New-Object System.IO.StreamWriter($LogFile, $true, [System.Text.Encoding]::UTF8) } catch {}

$script:LogBox = $null
$script:StatusTxt = $null
$script:MutedBrush = $null

function Write-Log {
  param(
    [string]$Message,
    [ValidateSet('INFO','SUCCESS','WARNING','ERROR')]
    [string]$Level = 'INFO'
  )

  $clean = [string]$Message
  $clean = $clean -replace '[^\u0009\u000A\u000D\u0020-\u007E]', ' '
  $clean = $clean -replace '\s{2,}', ' '
  $clean = $clean.Trim()
  if ([string]::IsNullOrWhiteSpace($clean)) { return }

  $line = "[{0}] {1}" -f $Level, $clean

  if ($script:LogSeen.Contains($line)) { return }
  $null = $script:LogSeen.Add($line)

  try {
    if ($script:LogWriter) { $script:LogWriter.WriteLine($line); $script:LogWriter.Flush() }
    else { $line | Out-File -FilePath $LogFile -Append -Encoding utf8 }
  } catch {}

  if ($script:StatusTxt) {
    $script:StatusTxt.Text = $clean
    switch ($Level) {
      'SUCCESS' { $script:StatusTxt.Foreground = $BrushTextOk }
      'WARNING' { $script:StatusTxt.Foreground = $BrushTextWarn }
      'ERROR'   { $script:StatusTxt.Foreground = $BrushTextBad }
      default   { $script:StatusTxt.Foreground = $BrushTextDark }
    }
  }

  if (-not $script:LogBox) { return }

  $brush = switch ($Level) {
    'SUCCESS' { $BrushSuccessUI }
    'WARNING' { $BrushWarnUI }
    'ERROR'   { $BrushErrorUI }
    default   { $BrushInfoUI }
  }

  $script:LogBox.Dispatcher.Invoke([action]{
    $para = New-Object Windows.Documents.Paragraph
    $para.Margin = '0,0,0,0'
    $para.LineHeight = 18
    $run = New-Object Windows.Documents.Run $line
    $run.Foreground = $brush
    $para.Inlines.Add($run)
    $script:LogBox.Document.Blocks.Add($para)
    $script:LogBox.ScrollToEnd()
  })
}

function Set-Busy {
  param([bool]$Busy)
  $script:IsBusy = $Busy
  if ($script:ProgressBar) {
    if ($Busy) {
      $script:ProgressBar.IsIndeterminate = $true
      $script:ProgressBar.Value = 0
    } else {
      $script:ProgressBar.IsIndeterminate = $false
    }
  }
}

function Guard-Action {
  param([string]$ActionName)
  if ($script:IsBusy) {
    Write-Log ("Another action is running. Please wait before starting: {0}" -f $ActionName) "WARNING"
    return $false
  }
  return $true
}

function Get-FolderSizeMB {
  param([Parameter(Mandatory)][string]$Path)
  try {
    $sum = (Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction Stop | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $sum) { $sum = 0 }
    return [math]::Round(($sum / 1MB), 2)
  } catch { return $null }
}

function Format-FileSize {
  param([long]$Bytes)
  if ($Bytes -lt 1KB) { return ("{0} B" -f $Bytes) }
  if ($Bytes -lt 1MB) { return ("{0:N2} KB" -f ($Bytes / 1KB)) }
  return ("{0:N2} MB" -f ($Bytes / 1MB))
}

function Normalize-FullPath {
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
  try { return [System.IO.Path]::GetFullPath($Path.Trim()) } catch { return $null }
}

function Is-ChildPath {
  param(
    [Parameter(Mandatory)][string]$Parent,
    [Parameter(Mandatory)][string]$Child
  )
  $p = (Normalize-FullPath $Parent)
  $c = (Normalize-FullPath $Child)
  if (-not $p -or -not $c) { return $false }
  if (-not $p.EndsWith('\')) { $p += '\' }
  return $c.StartsWith($p, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-InstallerCandidates {
  param([Parameter(Mandatory)][string]$Folder)
  if (-not (Test-Path $Folder)) { return @() }
  try {
    return Get-ChildItem -LiteralPath $Folder -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Extension -match '^\.(exe|msi|ps1)$' } |
      Sort-Object Name
  } catch { return @() }
}

function Auto-Detect-SourceFile {
  param(
    [Parameter(Mandatory)][string]$Folder,
    [bool]$Log = $false
  )

  if (-not $Folder -or -not (Test-Path $Folder)) {
    $script:SetupFilePath = $null
    if ($SetupFileTxt) { $SetupFileTxt.Text = "" }
    return
  }

  $candidates = @(Get-InstallerCandidates -Folder $Folder)
  if ($candidates.Count -gt 0) {
    $first = $candidates[0]
    $script:SetupFilePath = $first.FullName
    if ($SetupFileTxt) { $SetupFileTxt.Text = $first.Name }
    if ($Log) {
      if ($candidates.Count -gt 1) {
        Write-Log ("Multiple installers found ({0}); auto-selected: {1}" -f $candidates.Count, $first.Name) "SUCCESS"
      } else {
        Write-Log ("Setup file auto-selected: {0}" -f $first.Name) "SUCCESS"
      }
    }
  } else {
    $script:SetupFilePath = $null
    if ($SetupFileTxt) { $SetupFileTxt.Text = "" }
    if ($Log) { Write-Log "No installer (.exe, .msi or .ps1) found in source folder." "WARNING" }
  }
}

#endregion

#region -------------------- Safe XAML loader --------------------
function ConvertTo-XamlWindow {
  param([Parameter(Mandatory)][string]$Xaml)
  $clean = $Xaml -replace '[\uFEFF\u200B\u200C\u200D\u200E\u200F\u202A-\u202E]', ''
  $clean = $clean.TrimStart()
  if ($clean.Length -eq 0 -or $clean[0] -ne '<') { throw "XAML must start with '<'." }
  try { return [Windows.Markup.XamlReader]::Parse($clean) }
  catch {
    $settings = New-Object System.Xml.XmlReaderSettings
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Ignore
    $sr = New-Object System.IO.StringReader($clean)
    $xr = [System.Xml.XmlReader]::Create($sr, $settings)
    return [Windows.Markup.XamlReader]::Load($xr)
  }
}
#endregion

#region -------------------- XAML --------------------
$xamlText = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Intune Package Manager"
        Width="980" Height="660"
        WindowStartupLocation="CenterScreen"
        Background="#F6F8FB"
        FontFamily="Segoe UI"
        FontSize="13"
        UseLayoutRounding="True"
        SnapsToDevicePixels="True">

  <Window.Resources>
    <DropShadowEffect x:Key="ShadowPrimary" BlurRadius="10" ShadowDepth="0" Opacity="0.55" Color="#9FAEF7"/>
    <DropShadowEffect x:Key="ShadowBlue"    BlurRadius="10" ShadowDepth="0" Opacity="0.55" Color="#8FB4FF"/>
    <DropShadowEffect x:Key="ShadowGreen"   BlurRadius="10" ShadowDepth="0" Opacity="0.55" Color="#9FD7B8"/>
    <DropShadowEffect x:Key="ShadowRed"     BlurRadius="10" ShadowDepth="0" Opacity="0.55" Color="#F7C4C4"/>

    <Style x:Key="BtnBase" TargetType="Button">
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Padding" Value="12,0"/>
      <Setter Property="Height" Value="32"/>
      <Setter Property="MinWidth" Value="96"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Style.Triggers>
        <Trigger Property="IsEnabled" Value="False">
          <Setter Property="Effect" Value="{x:Null}"/>
          <Setter Property="Background" Value="#ECEFF3"/>
          <Setter Property="Foreground" Value="#9CA3AF"/>
          <Setter Property="Opacity" Value="0.75"/>
          <Setter Property="Cursor" Value="Arrow"/>
        </Trigger>
      </Style.Triggers>
    </Style>

    <Style x:Key="BtnPrimary" TargetType="Button" BasedOn="{StaticResource BtnBase}">
      <Setter Property="Background" Value="#9FAEF7"/>
      <Setter Property="Foreground" Value="#1F2D3A"/>
      <Setter Property="Effect" Value="{StaticResource ShadowPrimary}"/>
    </Style>
    <Style x:Key="BtnBlue" TargetType="Button" BasedOn="{StaticResource BtnBase}">
      <Setter Property="Background" Value="#8FB4FF"/>
      <Setter Property="Foreground" Value="#1F2D3A"/>
      <Setter Property="Effect" Value="{StaticResource ShadowBlue}"/>
    </Style>
    <Style x:Key="BtnGreen" TargetType="Button" BasedOn="{StaticResource BtnBase}">
      <Setter Property="Background" Value="#9FD7B8"/>
      <Setter Property="Foreground" Value="#1F2D3A"/>
      <Setter Property="Effect" Value="{StaticResource ShadowGreen}"/>
    </Style>
    <Style x:Key="BtnRed" TargetType="Button" BasedOn="{StaticResource BtnBase}">
      <Setter Property="Background" Value="#F7C4C4"/>
      <Setter Property="Foreground" Value="#1F2D3A"/>
      <Setter Property="Effect" Value="{StaticResource ShadowRed}"/>
    </Style>

    <SolidColorBrush x:Key="CardBg" Color="#FFFFFF"/>
    <SolidColorBrush x:Key="Line"   Color="#E6EBF4"/>
    <SolidColorBrush x:Key="Muted"  Color="#5F6B7A"/>
    <SolidColorBrush x:Key="Title"  Color="#1F2D3A"/>
  </Window.Resources>

  <Grid>
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="270"/>
      <ColumnDefinition Width="*"/>
    </Grid.ColumnDefinitions>

    <!-- ================= Sidebar ================= -->
    <Border Grid.Column="0" Background="{StaticResource CardBg}" BorderBrush="{StaticResource Line}" BorderThickness="0,0,1,0">
      <DockPanel LastChildFill="True">

        <!-- App Header -->
        <StackPanel DockPanel.Dock="Top" Margin="18,18,18,12">
          <StackPanel Orientation="Horizontal">
            <Border Width="36" Height="36" Background="#9AB8FF" CornerRadius="6">
              <TextBlock Text="W" Foreground="#1F2D3A" FontSize="18" FontWeight="Bold"
                         VerticalAlignment="Center" HorizontalAlignment="Center"/>
            </Border>
            <StackPanel Margin="10,0,0,0">
              <TextBlock Text="Intune Package Manager" FontSize="16" FontWeight="SemiBold" Foreground="{StaticResource Title}"/>
              <TextBlock Text="Win32 Packaging/Extraction Tool" FontSize="11" Foreground="{StaticResource Muted}"/>
            </StackPanel>
          </StackPanel>
        </StackPanel>

        <!-- Footer -->
        <Border DockPanel.Dock="Bottom" BorderBrush="{StaticResource Line}" BorderThickness="0,1,0,0" Padding="14" Background="{StaticResource CardBg}">
          <StackPanel>
            <TextBlock Text="Intune Package Manager" FontSize="13" FontWeight="Bold" Foreground="#1F2D3A"/>
            <TextBlock Text="Version 3.5" FontSize="11" Foreground="#5F6B7A" Margin="0,4,0,0"/>
            <TextBlock FontSize="11" Foreground="#7C8BA1" Margin="0,8,0,0">
              <Run Text="© 2026 "/>
            </TextBlock>
          </StackPanel>
        </Border>

        <!-- Nav -->
        <StackPanel DockPanel.Dock="Top" Margin="8,8">
          <TextBlock Text="TOOLS" Margin="14,10,0,6" FontSize="11" FontWeight="SemiBold" Foreground="#7C8BA1"/>
          <Button x:Name="NavCreateBtn" Content="Create Package" Height="38" Margin="6,6,6,2" Padding="12,0"
                  HorizontalContentAlignment="Left"
                  Background="#D8E2F4" Foreground="#1F2D3A" BorderThickness="0"/>
          <Button x:Name="NavExtractBtn" Content="Extract Package" Height="38" Margin="6,2,6,6" Padding="12,0"
                  HorizontalContentAlignment="Left"
                  Background="Transparent" Foreground="#7C8BA1" BorderThickness="0"/>
        </StackPanel>

        <!-- System Status -->
        <StackPanel DockPanel.Dock="Top" Margin="8,0">
          <TextBlock Text="SYSTEM" Margin="14,10,0,6" FontSize="11" FontWeight="SemiBold" Foreground="#7C8BA1"/>
          <Border Background="#F1F5F9" CornerRadius="6" Padding="12" Margin="6">
            <StackPanel>
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions> 
                    <StackPanel Grid.Column="0">
                       <TextBlock Text="Win32 Prep Tool" FontSize="12" FontWeight="SemiBold" Foreground="#1F2D3A"/>
                       <TextBlock x:Name="ToolStatusTxt" Text="Checking..." FontSize="11" Foreground="#5F6B7A" Margin="0,2,0,0"/>
                    </StackPanel>
                    <Button x:Name="UpdateToolBtn" Grid.Column="1" Content="Check" Style="{StaticResource BtnBlue}" Height="24" Width="50" FontSize="11" VerticalAlignment="Center"/>
                </Grid>
                <ProgressBar x:Name="UpdateProgress" Height="4" Margin="0,8,0,0" Value="0" Visibility="Collapsed"/>
            </StackPanel>
          </Border>
        </StackPanel>

        <!-- Session + About -->
        <Grid>
          <StackPanel VerticalAlignment="Bottom">

            <Border Margin="12,0,12,8" Background="#F9FBFF" BorderBrush="{StaticResource Line}" BorderThickness="1" CornerRadius="6" Padding="12">
              <StackPanel>
                <TextBlock Text="Session" FontSize="12" FontWeight="SemiBold" Foreground="#0F172A" Margin="0,0,0,8"/>
                <Grid>
                  <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                  </Grid.ColumnDefinitions>
                  <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                  </Grid.RowDefinitions>

                  <TextBlock Grid.Row="0" Grid.Column="0" Text="Machine:" Foreground="#111827" FontWeight="SemiBold" Margin="0,0,8,6"/>
                  <Border Grid.Row="0" Grid.Column="1" Background="#EEF2FF" Padding="6,2" CornerRadius="4" Margin="0,0,0,6">
                    <TextBlock x:Name="SessionMachineTxt" Text="..." Foreground="#1D4ED8"/>
                  </Border>

                  <TextBlock Grid.Row="1" Grid.Column="0" Text="User:" Foreground="#111827" FontWeight="SemiBold" Margin="0,0,8,6"/>
                  <Border Grid.Row="1" Grid.Column="1" Background="#ECFDF3" Padding="6,2" CornerRadius="4" Margin="0,0,0,6">
                    <TextBlock x:Name="SessionUserTxt" Text="..." Foreground="#166534"/>
                  </Border>

                  <TextBlock Grid.Row="2" Grid.Column="0" Text="Elevation:" Foreground="#111827" FontWeight="SemiBold" Margin="0,0,8,0"/>
                  <Border BorderBrush="#E5E7EB" BorderThickness="0" Grid.Row="2" Grid.Column="1" x:Name="SessionElevationPill" Background="#FEF2F2" Padding="6,2" CornerRadius="4">
                    <TextBlock x:Name="SessionElevationTxt" Text="..." Foreground="#991B1B"/>
                  </Border>
                </Grid>
              </StackPanel>
            </Border>
          </StackPanel>
        </Grid>

      </DockPanel>
    </Border>

    <!-- ================= Main Content ================= -->
    <Grid Grid.Column="1">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <!-- Header -->
      <Border Grid.Row="0" Padding="18,14,18,10" Background="#F6F8FB">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
          </Grid.ColumnDefinitions>
          <StackPanel Grid.Column="0">
            <TextBlock Text="Create Intune Win32 packages (.intunewin) from EXE/MSI/PS1 or Extract .intunewin packages." FontSize="14" Foreground="{StaticResource Title}"/>
            <TextBlock Text=""
                       FontSize="14" Foreground="{StaticResource Muted}" Margin="0,6,0,0"/>
          </StackPanel>
        </Grid>
      </Border>

      <!-- Body -->
      <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
        <Grid Margin="16,0,16,14">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>

          <Grid Grid.Row="0">
            <!-- View: Create -->
            <Grid x:Name="ViewCreate">
              <!-- Package Details -->
              <Border Background="{StaticResource CardBg}" CornerRadius="6" BorderBrush="{StaticResource Line}" BorderThickness="1" Padding="12" Margin="0,0,0,10">
            <StackPanel>
              <TextBlock Text="Package Details" FontSize="13" FontWeight="SemiBold" Foreground="#0F172A" Margin="0,0,0,10"/>

              <Grid>
                <Grid.RowDefinitions>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="6"/>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="6"/>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="6"/>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="10"/>
                  <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>

                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="150"/>
                  <ColumnDefinition Width="*"/>
                  <ColumnDefinition Width="95"/>
                </Grid.ColumnDefinitions>

                <TextBlock Grid.Row="0" Grid.Column="0" Text="Source Folder:" Foreground="{StaticResource Title}" VerticalAlignment="Center"/>
                <TextBox x:Name="SrcFolderTxt" Grid.Row="0" Grid.Column="1" Height="28" Margin="0,0,8,0"
                         Background="#F1F5F9" BorderBrush="{StaticResource Line}" BorderThickness="1"/>
                <Button x:Name="SrcFolderBtn" Grid.Row="0" Grid.Column="2" Content="Browse" Style="{StaticResource BtnBlue}" Height="28"/>

                <TextBlock Grid.Row="2" Grid.Column="0" Text="Source File:" Foreground="{StaticResource Title}" VerticalAlignment="Center"/>
                <TextBox x:Name="SetupFileTxt" Grid.Row="2" Grid.Column="1" Height="28" Margin="0,0,8,0"
                         Background="#F1F5F9" BorderBrush="{StaticResource Line}" BorderThickness="1" IsReadOnly="True"/>
                <Button x:Name="SetupFileBtn" Grid.Row="2" Grid.Column="2" Content="Browse" Style="{StaticResource BtnBlue}" Height="28"/>

                <TextBlock Grid.Row="4" Grid.Column="0" Text="Output Folder:" Foreground="{StaticResource Title}" VerticalAlignment="Center"/>
                <StackPanel Grid.Row="4" Grid.Column="1" Grid.ColumnSpan="2" Orientation="Horizontal">
                  <RadioButton x:Name="OutSameRadio" Content="Same as source" GroupName="OutMode" Margin="0,0,16,0"/>
                  <RadioButton x:Name="OutCustomRadio" Content="Custom folder" GroupName="OutMode" IsChecked="True"/>
                </StackPanel>

                <TextBlock Grid.Row="6" Grid.Column="0" Text="Output Path:" Foreground="{StaticResource Title}" VerticalAlignment="Center"/>
                <TextBox x:Name="OutFolderTxt" Grid.Row="6" Grid.Column="1" Height="28" Margin="0,0,8,0"
                         Background="#F1F5F9" BorderBrush="{StaticResource Line}" BorderThickness="1"/>
                <Button x:Name="OutFolderBtn" Grid.Row="6" Grid.Column="2" Content="Browse" Style="{StaticResource BtnBlue}" Height="28"/>

                <StackPanel Grid.Row="8" Grid.Column="0" Grid.ColumnSpan="3" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,6,0,0">
                  <Button x:Name="CreateBtn" Content="Create Package" Style="{StaticResource BtnPrimary}" Margin="0,0,8,0"/>
                  <Button x:Name="OpenOutBtn" Content="Open Output" Style="{StaticResource BtnGreen}" Margin="0,0,8,0"/>
                  <Button x:Name="ClearBtn" Content="Clear" Style="{StaticResource BtnBlue}" Margin="0,0,8,0"/>
                </StackPanel>

              </Grid>

              <Border Background="#F9FBFF" BorderBrush="{StaticResource Line}" BorderThickness="1" CornerRadius="6" Padding="10" Margin="0,10,0,0">
                <Grid>
                  <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                  </Grid.RowDefinitions>
                  <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="100"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="90"/>
                    <ColumnDefinition Width="70"/>
                  </Grid.ColumnDefinitions>

                  <TextBlock Text="Source Package:" Grid.Row="0" Grid.Column="0" Foreground="{StaticResource Title}" Margin="0,0,8,0" VerticalAlignment="Center"/>
                  <TextBlock x:Name="PkgNameTxt" Grid.Row="0" Grid.Column="1" Foreground="{StaticResource Muted}" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>

                  <TextBlock Text="Source Size:" Grid.Row="0" Grid.Column="2" Foreground="{StaticResource Title}" Margin="8,0,8,0" VerticalAlignment="Center"/>
                  <TextBlock x:Name="SrcSizeTxt" Grid.Row="0" Grid.Column="3" Foreground="{StaticResource Muted}" Text="--" VerticalAlignment="Center" HorizontalAlignment="Left"/>

                  <TextBlock Text="Output Package:" Grid.Row="1" Grid.Column="0" Foreground="{StaticResource Title}" Margin="0,8,8,0" VerticalAlignment="Center"/>
                  <TextBlock x:Name="OutPathInfoTxt" Grid.Row="1" Grid.Column="1" Foreground="{StaticResource Muted}" Margin="0,8,8,0" Text="" TextTrimming="CharacterEllipsis" VerticalAlignment="Center"/>

                  <TextBlock Text="Output Size:" Grid.Row="1" Grid.Column="2" Foreground="{StaticResource Title}" Margin="8,5,8,0" VerticalAlignment="Center"/>
                  <TextBlock x:Name="OutFileInfoTxt" Grid.Row="1" Grid.Column="3" Foreground="{StaticResource Muted}" Margin="0,5,8,0" Text="" TextTrimming="CharacterEllipsis" VerticalAlignment="Center" HorizontalAlignment="Left"/>
                </Grid>
              </Border>

            </StackPanel>
          </Border>
        </Grid>

        <!-- View: Extract -->
        <Grid x:Name="ViewExtract" Visibility="Collapsed">
          <Border Background="{StaticResource CardBg}" CornerRadius="6" BorderBrush="{StaticResource Line}" BorderThickness="1" Padding="12" Margin="0,0,0,10">
            <StackPanel>
              <TextBlock Text="Extract Package" FontSize="13" FontWeight="SemiBold" Foreground="#0F172A" Margin="0,0,0,10"/>
              <Grid>
                <Grid.RowDefinitions>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="6"/>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="6"/>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="10"/>
                  <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="150"/>
                  <ColumnDefinition Width="*"/>
                  <ColumnDefinition Width="95"/>
                </Grid.ColumnDefinitions>

                <TextBlock Grid.Row="0" Grid.Column="0" Text="IntuneWin File:" Foreground="{StaticResource Title}" VerticalAlignment="Center"/>
                <TextBox x:Name="ExtractFileTxt" Grid.Row="0" Grid.Column="1" Height="28" Margin="0,0,8,0" Background="#F1F5F9" BorderBrush="{StaticResource Line}" BorderThickness="1" IsReadOnly="True"/>
                <Button x:Name="ExtractFileBtn" Grid.Row="0" Grid.Column="2" Content="Browse" Style="{StaticResource BtnBlue}" Height="28"/>

                <TextBlock Grid.Row="2" Grid.Column="0" Text="Destination Folder:" Foreground="{StaticResource Title}" VerticalAlignment="Center"/>
                <TextBox x:Name="ExtractDestTxt" Grid.Row="2" Grid.Column="1" Height="28" Margin="0,0,8,0" Background="#F1F5F9" BorderBrush="{StaticResource Line}" BorderThickness="1"/>
                <Button x:Name="ExtractDestBtn" Grid.Row="2" Grid.Column="2" Content="Browse" Style="{StaticResource BtnBlue}" Height="28"/>

                <TextBlock Grid.Row="4" Grid.Column="0" Text="Intune App (name/id):" Foreground="{StaticResource Title}" VerticalAlignment="Center"/>
                <TextBox x:Name="ExtractIntuneQueryTxt" Grid.Row="4" Grid.Column="1" Height="28" Margin="0,0,8,0" Background="#F1F5F9" BorderBrush="{StaticResource Line}" BorderThickness="1"/>
                <StackPanel Grid.Row="4" Grid.Column="2" Orientation="Horizontal" HorizontalAlignment="Right">
                  <Button x:Name="ExtractPullGraphBtn" Content="Graph" Style="{StaticResource BtnBlue}" Height="28" Margin="0,0,4,0" Width="55"/>
                  <Button x:Name="ExtractPullDeviceBtn" Content="Pull" Style="{StaticResource BtnBlue}" Height="28" Width="55"/>
                </StackPanel>

                <StackPanel Grid.Row="6" Grid.Column="0" Grid.ColumnSpan="3" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,6,0,0">
                  <Button x:Name="ExtractRunBtn" Content="Extract" Style="{StaticResource BtnPrimary}" Margin="0,0,8,0"/>
                  <Button x:Name="ExtractOpenBtn" Content="Open Folder" Style="{StaticResource BtnGreen}" Margin="0,0,8,0" IsEnabled="False"/>
                </StackPanel>
              </Grid>
            </StackPanel>
          </Border>
        </Grid>
      </Grid>

          <!-- Message Center -->
          <Border Grid.Row="1" Background="{StaticResource CardBg}" CornerRadius="6" BorderBrush="{StaticResource Line}" BorderThickness="1" Padding="12" Margin="0,0,0,10">
            <StackPanel>
              <TextBlock Text="MESSAGE CENTER" FontSize="13" FontWeight="SemiBold" Foreground="#0F172A" Margin="0,0,0,8"/>
              <RichTextBox x:Name="LogBox" Height="120" IsReadOnly="True"
                           Background="#1F2D3A" Foreground="#E4E9F0"
                           BorderBrush="#1F2937" BorderThickness="1"
                           FontFamily="Consolas" FontSize="13"
                           VerticalScrollBarVisibility="Auto"
                           Padding="10"/>
            </StackPanel>
          </Border>

          <!-- Status Bar -->
          <Border Grid.Row="2" Background="{StaticResource CardBg}" CornerRadius="6" BorderBrush="{StaticResource Line}" BorderThickness="1" Padding="10">
            <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="170"/>
            <ColumnDefinition Width="*"/>
          </Grid.ColumnDefinitions>

          <TextBlock x:Name="ClockTxt" Text="--" Foreground="{StaticResource Muted}" Grid.Column="0"/>
          <ProgressBar x:Name="ProgressBar" Value="0" Maximum="100" Height="12" Grid.Column="1" VerticalAlignment="Center"/>
        </Grid>
      </Border>

        </Grid>
      </ScrollViewer>

    </Grid>
  </Grid>
</Window>
'@
#endregion

#region -------------------- Create Window & refs --------------------
$w = ConvertTo-XamlWindow -Xaml $xamlText

try { $script:MutedBrush = $w.Resources['Muted'] } catch { $script:MutedBrush = $BrushTextDark }

# refs
$SessionMachineTxt = $w.FindName('SessionMachineTxt')
$SessionUserTxt = $w.FindName('SessionUserTxt')
$SessionElevationTxt = $w.FindName('SessionElevationTxt')
$SessionElevationPill = $w.FindName('SessionElevationPill')

$SrcFolderTxt = $w.FindName('SrcFolderTxt')
$SrcFolderBtn = $w.FindName('SrcFolderBtn')
$SetupFileTxt = $w.FindName('SetupFileTxt')
$SetupFileBtn = $w.FindName('SetupFileBtn')
$OutSameRadio = $w.FindName('OutSameRadio')
$OutCustomRadio = $w.FindName('OutCustomRadio')
$OutFolderTxt = $w.FindName('OutFolderTxt')
$OutFolderBtn = $w.FindName('OutFolderBtn')

$NavCreateBtn = $w.FindName('NavCreateBtn')
$NavExtractBtn = $w.FindName('NavExtractBtn')
$ViewCreate = $w.FindName('ViewCreate')
$ViewExtract = $w.FindName('ViewExtract')

$ExtractFileTxt = $w.FindName('ExtractFileTxt')
$ExtractFileBtn = $w.FindName('ExtractFileBtn')
$ExtractDestTxt = $w.FindName('ExtractDestTxt')
$ExtractDestBtn = $w.FindName('ExtractDestBtn')
$ExtractIntuneQueryTxt = $w.FindName('ExtractIntuneQueryTxt')
$ExtractPullGraphBtn = $w.FindName('ExtractPullGraphBtn')
$ExtractPullDeviceBtn = $w.FindName('ExtractPullDeviceBtn')
$ExtractRunBtn = $w.FindName('ExtractRunBtn')
$ExtractOpenBtn = $w.FindName('ExtractOpenBtn')

$CreateBtn = $w.FindName('CreateBtn')
$OpenOutBtn = $w.FindName('OpenOutBtn')
$ClearBtn = $w.FindName('ClearBtn')

$PkgNameTxt = $w.FindName('PkgNameTxt')
$SrcSizeTxt = $w.FindName('SrcSizeTxt')
$OutPathInfoTxt = $w.FindName('OutPathInfoTxt')
$OutFileInfoTxt = $w.FindName('OutFileInfoTxt')

$ToolStatusTxt = $w.FindName('ToolStatusTxt')
$UpdateToolBtn = $w.FindName('UpdateToolBtn')
$UpdateProgress = $w.FindName('UpdateProgress')

$ClockTxt = $w.FindName('ClockTxt')
$ProgressBar = $w.FindName('ProgressBar')
$script:ProgressBar = $ProgressBar
$script:LogBox = $w.FindName('LogBox')
$script:StatusTxt = $null

# session
$sessionMachine = $env:COMPUTERNAME
$sessionUser = if ($env:USERDOMAIN -and $env:USERNAME) { "{0}\{1}" -f $env:USERDOMAIN, $env:USERNAME } else { $env:USERNAME }
$isAdmin = (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$sessionElevation = if ($isAdmin) { 'Administrator' } else { 'Standard' }

$SessionMachineTxt.Text = $sessionMachine
$SessionUserTxt.Text = $sessionUser
$SessionElevationTxt.Text = $sessionElevation
if ($isAdmin) {
  $SessionElevationPill.Background = New-Brush "#ECFDF3"
  $SessionElevationTxt.Foreground = New-Brush "#166534"
} else {
  $SessionElevationPill.Background = New-Brush "#FEF2F2"
  $SessionElevationTxt.Foreground = New-Brush "#991B1B"
}

# defaults
$SrcFolderTxt.Text = $DefaultSourcePath
$OutFolderTxt.Text = $DefaultOutputPath
$OpenOutBtn.IsEnabled = $true
Auto-Detect-SourceFile -Folder $DefaultSourcePath -Log $true
#endregion

#region -------------------- UI logic --------------------
function Refresh-UI {
  # IntuneWinAppUtil presence
  if (-not (Test-Path $IntuneWinUtil)) {
    Write-Log ("IntuneWinAppUtil.exe not found in script folder: {0}" -f $IntuneWinUtil) "WARNING"
  }

  $src = Normalize-FullPath $SrcFolderTxt.Text
  if ($SrcSizeTxt) { $SrcSizeTxt.Text = "--" }

  if (-not $script:SetupFilePath -and $src -and (Test-Path $src)) {
    Auto-Detect-SourceFile -Folder $src -Log $false
  }

  $setupPath = if ($script:SetupFilePath) { $script:SetupFilePath } else { $SetupFileTxt.Text }
  $setup = Normalize-FullPath $setupPath
  $setupName = $null
  if ($setup) {
    $setupName = [System.IO.Path]::GetFileName($setup)
    $PkgNameTxt.Text = $setupName
    if ($SrcSizeTxt -and (Test-Path $setup)) {
      try {
        $fi = Get-Item -LiteralPath $setup -ErrorAction SilentlyContinue
        if ($fi) { $SrcSizeTxt.Text = (Format-FileSize -Bytes $fi.Length) }
      } catch {}
    }
  } else {
    $PkgNameTxt.Text = ""
  }

  # output mode
  if ($OutSameRadio.IsChecked -eq $true) {
    $OutFolderTxt.IsEnabled = $false
    if ($src) { $OutFolderTxt.Text = $src }
  } else {
    $OutFolderTxt.IsEnabled = $true
    if (-not $OutFolderTxt.Text) { $OutFolderTxt.Text = $DefaultOutputPath }
    if ($src -and (Normalize-FullPath $OutFolderTxt.Text) -eq $src) { $OutFolderTxt.Text = $DefaultOutputPath }
  }

  $outInfo = Normalize-FullPath $OutFolderTxt.Text
  $outPkgName = ""
  $outPkgSize = ""
  $hasOutput = $false
  if ($outInfo -and (Test-Path $outInfo)) {
    try {
      $latest = Get-ChildItem -LiteralPath $outInfo -Filter *.intunewin -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
        if ($latest) {
          $hasOutput = $true
          $outPkgName = $latest.Name
          $outPkgSize = (Format-FileSize -Bytes $latest.Length)
        }
      } catch {}
    }

  if ($OutPathInfoTxt) {
    $OutPathInfoTxt.Text = $outPkgName
    $OutPathInfoTxt.Foreground = if ($hasOutput) { $BrushTextOk } else { $script:MutedBrush }
  }
  if ($OutFileInfoTxt) {
    $OutFileInfoTxt.Text = $outPkgSize
    $OutFileInfoTxt.Foreground = if ($hasOutput) { $BrushTextOk } else { $script:MutedBrush }
  }
  if ($SetupFileTxt) {
    if ($setupName) {
      if ($SetupFileTxt.Text -ne $setupName) { $SetupFileTxt.Text = $setupName }
    }
  }

  # buttons enabled/disabled
  $CreateBtn.IsEnabled = -not $script:IsBusy
  $SrcFolderBtn.IsEnabled = -not $script:IsBusy
  $SetupFileBtn.IsEnabled = -not $script:IsBusy
  $ClearBtn.IsEnabled = -not $script:IsBusy
  $OutSameRadio.IsEnabled = -not $script:IsBusy
  $OutCustomRadio.IsEnabled = -not $script:IsBusy
  $OutFolderBtn.IsEnabled = -not $script:IsBusy
  $OutFolderTxt.IsEnabled = (-not $script:IsBusy) -and ($OutCustomRadio.IsChecked -eq $true)

  $NavCreateBtn.IsEnabled = -not $script:IsBusy
  $NavExtractBtn.IsEnabled = -not $script:IsBusy
  $ExtractFileBtn.IsEnabled = -not $script:IsBusy
  $ExtractDestBtn.IsEnabled = -not $script:IsBusy
  $ExtractIntuneQueryTxt.IsEnabled = -not $script:IsBusy
  $ExtractPullGraphBtn.IsEnabled = -not $script:IsBusy
  $ExtractPullDeviceBtn.IsEnabled = -not $script:IsBusy
  $ExtractRunBtn.IsEnabled = -not $script:IsBusy
  $ExtractOpenBtn.IsEnabled = -not $script:IsBusy
  
  $UpdateToolBtn.IsEnabled = -not $script:IsBusy
}

function Get-LocalToolVersion {
  if (-not (Test-Path $IntuneWinUtil)) { return $null }
  try {
     $ver = (Get-Item $IntuneWinUtil).VersionInfo.FileVersion
     if ($ver) { return $ver }
     return "Unknown"
  } catch { return "Unknown" }
}

function Check-ToolStatus {
  if (Test-Path $IntuneWinUtil) {
    $ver = Get-LocalToolVersion
    $ToolStatusTxt.Text = "Installed ($ver)"
    $ToolStatusTxt.Foreground = $BrushTextOk
    $UpdateToolBtn.Content = "Update"
  } else {
    $ToolStatusTxt.Text = "Not Found"
    $ToolStatusTxt.Foreground = $script:MutedBrush # or Red if we had it
    $UpdateToolBtn.Content = "Install"
  }
}

function Validate-Inputs {
  $src = Normalize-FullPath $SrcFolderTxt.Text
  if (-not $src -or -not (Test-Path $src)) { Write-Log "Source folder is invalid or not found." "ERROR"; return $null }

  $setupPath = if ($script:SetupFilePath) { $script:SetupFilePath } else { $SetupFileTxt.Text }
  $setup = Normalize-FullPath $setupPath
  if (-not $setup -or -not (Test-Path $setup)) { Write-Log "Setup file is invalid or not found." "ERROR"; return $null }

  $ext = [System.IO.Path]::GetExtension($setup).ToLower()
  if ($ext -ne '.exe' -and $ext -ne '.msi' -and $ext -ne '.ps1') { Write-Log "Setup file must be .exe, .msi or .ps1" "ERROR"; return $null }

  if (-not (Is-ChildPath -Parent $src -Child $setup)) {
    Write-Log "Setup file must be inside the selected Source folder." "ERROR"
    return $null
  }

  $out = Normalize-FullPath $OutFolderTxt.Text
  if (-not $out) { Write-Log "Output folder is empty." "ERROR"; return $null }
  if (-not (Test-Path $out)) {
    try { $null = New-Item -ItemType Directory -Path $out -Force -ErrorAction Stop | Out-Null }
    catch { Write-Log ("Failed to create output folder: {0}" -f $_.Exception.Message) "ERROR"; return $null }
  }

  if (-not (Test-Path $IntuneWinUtil)) {
    Write-Log ("IntuneWinAppUtil.exe not found: {0}" -f $IntuneWinUtil) "ERROR"
    return $null
  }

  return [pscustomobject]@{ SourceFolder=$src; SetupFile=$setup; OutputFolder=$out; UtilPath=$IntuneWinUtil }
}

function Get-MgGraphAllPages {
  param([Parameter(Mandatory)][string]$Uri)

  $all = @()
  $next = $Uri
  do {
    $resp = Invoke-MgGraphRequest -Uri $next -Method GET -OutputType PSObject
    if ($resp.value) { $all += @($resp.value) }
    $next = $resp.'@odata.nextLink'
  } while ($next)

  return $all
}

function Ensure-GraphConnection {
  try {
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop | Out-Null
  }
  catch {
    throw "Microsoft.Graph.Authentication module is required. Install it first (Install-Module Microsoft.Graph -Scope CurrentUser)."
  }

  $ctx = $null
  try { $ctx = Get-MgContext } catch {}

  if (-not $ctx) {
    throw "No active Microsoft Graph session found. Connect before running this script (e.g. Connect-MgGraph -Scopes DeviceManagementApps.Read.All)."
  }

  $hasScope = $false
  try {
    if ($ctx.Scopes -and ($ctx.Scopes -contains 'DeviceManagementApps.Read.All' -or $ctx.Scopes -contains 'DeviceManagementApps.ReadWrite.All')) {
      $hasScope = $true
    }
  } catch {}

  if (-not $hasScope) {
    throw "Current Graph session is missing required scope. Reconnect with DeviceManagementApps.Read.All or DeviceManagementApps.ReadWrite.All."
  }
}

function Get-IntuneWinFromIntune {
  param(
    [Parameter(Mandatory)][string]$AppQuery,
    [Parameter(Mandatory)][string]$DestinationFolder
  )

  Add-Type -AssemblyName System.IO.Compression.FileSystem
  Ensure-GraphConnection

  Write-Log "Querying Intune Win32 apps..." "INFO"
  $appsUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?`$filter=isof('microsoft.graph.win32LobApp')&`$select=id,displayName"
  $apps = Get-MgGraphAllPages -Uri $appsUri

  if (-not $apps -or $apps.Count -eq 0) {
    throw "No Win32 apps returned from Intune."
  }

  $matches = @()
  $guid = [guid]::Empty
  if ([guid]::TryParse($AppQuery, [ref]$guid)) {
    $matches = @($apps | Where-Object { $_.id -eq $AppQuery })
  }
  else {
    $matches = @($apps | Where-Object { $_.displayName -and $_.displayName -like "*$AppQuery*" })
  }

  if (-not $matches -or $matches.Count -eq 0) {
    throw "No Win32 app matched '$AppQuery'."
  }

  if ($matches.Count -gt 1) {
    $top = $matches | Select-Object -First 5
    $names = ($top | ForEach-Object { "{0} ({1})" -f $_.displayName, $_.id }) -join '; '
    throw "Multiple apps matched '$AppQuery'. Please be more specific. Matches: $names"
  }

  $app = $matches[0]
  Write-Log ("Selected Intune app: {0} ({1})" -f $app.displayName, $app.id) "INFO"

  $versionsUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($app.id)/microsoft.graph.win32LobApp/contentVersions"
  $versions = Get-MgGraphAllPages -Uri $versionsUri
  if (-not $versions -or $versions.Count -eq 0) {
    throw "No content versions found for app '$($app.displayName)'."
  }

  $version = $versions |
    Sort-Object -Property @{ Expression = { if ($_.createdDateTime) { [datetime]$_.createdDateTime } else { [datetime]::MinValue } } } -Descending |
    Select-Object -First 1

  Write-Log ("Using content version: {0}" -f $version.id) "INFO"

  $filesUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($app.id)/microsoft.graph.win32LobApp/contentVersions/$($version.id)/files"
  $files = Get-MgGraphAllPages -Uri $filesUri
  if (-not $files -or $files.Count -eq 0) {
    throw "No content files found for app '$($app.displayName)' version '$($version.id)'."
  }

  # Some tenants only expose download URI/encryption data from the per-file detail endpoint.
  $candidateFiles = @($files | Where-Object { $_.isCommitted -eq $true })
  if (-not $candidateFiles -or $candidateFiles.Count -eq 0) {
    $stateDetails = ($files | Select-Object -First 5 | ForEach-Object {
      $name = if ($_.name) { $_.name } else { $_.id }
      $commit = if ($null -ne $_.isCommitted) { $_.isCommitted } else { 'n/a' }
      $upload = if ($_.uploadState) { $_.uploadState } else { 'n/a' }
      "{0}: committed={1}, uploadState={2}" -f $name, $commit, $upload
    }) -join '; '
    throw "No committed content files were returned by Intune. File states: $stateDetails"
  }

  $file = $null
  $downloadUri = $null
  $enc = $null

  foreach ($candidate in ($candidateFiles | Sort-Object -Property @{ Expression = { if ($_.sizeEncrypted) { [int64]$_.sizeEncrypted } else { 0 } } } -Descending)) {
    $detail = $null
    try {
      $detailUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($app.id)/microsoft.graph.win32LobApp/contentVersions/$($version.id)/files/$($candidate.id)"
      $detail = Invoke-MgGraphRequest -Uri $detailUri -Method GET -OutputType PSObject
    }
    catch {
      continue
    }

    $detailProps = $null
    if ($detail -and $detail.PSObject.Properties.Name -contains 'AdditionalProperties') {
      $detailProps = $detail.AdditionalProperties
    }

    $committedContentFile = $null
    if ($detail.committedContentFile) {
      $committedContentFile = $detail.committedContentFile
    }
    elseif ($detailProps -is [System.Collections.IDictionary] -and $detailProps.Contains('committedContentFile')) {
      $committedContentFile = $detailProps['committedContentFile']
    }

    $candidateUri = $null
    if ($detail.azureStorageUri) {
      $candidateUri = [string]$detail.azureStorageUri
    }
    elseif ($detailProps -is [System.Collections.IDictionary] -and $detailProps.Contains('azureStorageUri')) {
      $candidateUri = [string]$detailProps['azureStorageUri']
    }
    elseif ($committedContentFile -and $committedContentFile.azureStorageUri) {
      $candidateUri = [string]$committedContentFile.azureStorageUri
    }
    elseif ($committedContentFile -is [System.Collections.IDictionary] -and $committedContentFile.Contains('azureStorageUri')) {
      $candidateUri = [string]$committedContentFile['azureStorageUri']
    }

    if (-not $candidateUri) { continue }

    $candidateEnc = $null
    if ($detail.encryptionInfo) {
      $candidateEnc = $detail.encryptionInfo
    }
    elseif ($detailProps -is [System.Collections.IDictionary] -and $detailProps.Contains('encryptionInfo')) {
      $candidateEnc = $detailProps['encryptionInfo']
    }
    elseif ($committedContentFile -and $committedContentFile.encryptionInfo) {
      $candidateEnc = $committedContentFile.encryptionInfo
    }
    elseif ($committedContentFile -is [System.Collections.IDictionary] -and $committedContentFile.Contains('encryptionInfo')) {
      $candidateEnc = $committedContentFile['encryptionInfo']
    }

    if (-not $candidateEnc) { continue }

    $file = if ($detail) { $detail } else { $candidate }
    $downloadUri = $candidateUri
    $enc = $candidateEnc
    break
  }

  if (-not $file -or -not $downloadUri) {
    $stateDetails = ($candidateFiles | Select-Object -First 5 | ForEach-Object {
      $name = if ($_.name) { $_.name } else { $_.id }
      $upload = if ($_.uploadState) { $_.uploadState } else { 'n/a' }
      "{0} (uploadState={1})" -f $name, $upload
    }) -join '; '
    throw "No committed content file with a downloadable URI was exposed by Graph for this app version. Candidate states: $stateDetails"
  }

  if (-not $enc) {
    throw "Downloaded content metadata does not contain encryptionInfo."
  }

  $encKey = if ($enc.encryptionKey) { $enc.encryptionKey } else { $enc.EncryptionKey }
  $iv = if ($enc.initializationVector) { $enc.initializationVector } else { $enc.InitializationVector }
  if (-not $encKey -or -not $iv) {
    throw "encryptionInfo is missing encryptionKey or initializationVector."
  }

  $payloadName = if ($file.name) { [System.IO.Path]::GetFileName([string]$file.name) } else { "IntuneWinPackage.intunewin" }
  if ([System.IO.Path]::GetExtension($payloadName) -ne ".intunewin") {
    $payloadName = "$payloadName.intunewin"
  }

  $safeAppName = ($app.displayName -replace '[\\/:*?"<>|]', '_')
  if ([string]::IsNullOrWhiteSpace($safeAppName)) { $safeAppName = $app.id }

  $stageDir = Join-Path $DestinationFolder ("_intune_pull_" + $safeAppName + "_" + [DateTime]::Now.ToString("yyyyMMddHHmmss"))
  New-Item -ItemType Directory -Path $stageDir -Force | Out-Null

  $payloadPath = Join-Path $stageDir $payloadName
  Write-Log ("Downloading encrypted payload: {0}" -f $payloadName) "INFO"
  Invoke-WebRequest -Uri $downloadUri -OutFile $payloadPath -UseBasicParsing

  if (-not (Test-Path $payloadPath)) {
    throw "Payload download failed."
  }

  $xmlPath = Join-Path $stageDir "detection.xml"
  $escapedPayload = [System.Security.SecurityElement]::Escape($payloadName)
  $escapedKey = [System.Security.SecurityElement]::Escape([string]$encKey)
  $escapedIv = [System.Security.SecurityElement]::Escape([string]$iv)

  $xmlContent = @"
<ApplicationInfo>
  <FileName>$escapedPayload</FileName>
  <EncryptionInfo>
    <EncryptionKey>$escapedKey</EncryptionKey>
    <InitializationVector>$escapedIv</InitializationVector>
  </EncryptionInfo>
</ApplicationInfo>
"@

  Set-Content -Path $xmlPath -Value $xmlContent -Encoding UTF8

  $wrapperPath = Join-Path $DestinationFolder ("Downloaded_" + $safeAppName + ".intunewin")
  if (Test-Path $wrapperPath) { Remove-Item $wrapperPath -Force }
  [System.IO.Compression.ZipFile]::CreateFromDirectory($stageDir, $wrapperPath)

  if (-not (Test-Path $wrapperPath)) {
    throw "Failed to build local .intunewin wrapper package."
  }

  Write-Log ("Downloaded package created: {0}" -f $wrapperPath) "SUCCESS"
  return $wrapperPath
}

#endregion

#region MTLS Device Certificate Download Functions (Alternative Intune Pull Method)

# Invoke HTTPS request using device MDM certificate for mutual TLS auth
function Invoke-MtlsRestRequest {
  param(
    [string]$Url,
    [string]$Method = "PUT",
    [string]$Body,
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$Cert,
    [hashtable]$Headers
  )

  try {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

    $req = [System.Net.HttpWebRequest]::Create($Url)
    $req.Method = $Method
    $req.ContentType = "application/json; charset=utf-8"
    $req.Timeout = 60000
    $req.ReadWriteTimeout = 60000
    $req.Accept = "application/json"
    if ($Cert) { $null = $req.ClientCertificates.Add($Cert) }

    if ($Headers) {
      foreach ($key in $Headers.Keys) {
        if ($key -ne "Content-Type") {
          $req.Headers[$key] = [string]$Headers[$key]
        }
      }
    }

    if ($Body) {
      $bytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
      $req.ContentLength = $bytes.Length
      $stream = $req.GetRequestStream()
      $stream.Write($bytes, 0, $bytes.Length)
      $stream.Close()
    } else {
      $req.ContentLength = 0
    }

    $resp = $req.GetResponse()
    $reader = New-Object IO.StreamReader $resp.GetResponseStream()
    $result = $reader.ReadToEnd()
    $reader.Close()
    $resp.Close()
    return $result
  } catch {
    $status = $null
    $respBody = $null
    try {
      if ($_.Exception.Response) {
        $status = [int]$_.Exception.Response.StatusCode
        $stream = $_.Exception.Response.GetResponseStream()
        if ($stream) {
          $reader = New-Object IO.StreamReader $stream
          $respBody = $reader.ReadToEnd()
          $reader.Close()
        }
      }
    } catch { }

    if ($status) {
      if (-not $respBody) { $respBody = "<no response body>" }
      Write-Log ("MTLS request failed: Method={0} Url={1} Status={2} Body={3}" -f $Method, $Url, $status, $respBody) "ERROR"
    } else {
      Write-Log ("MTLS request exception: Method={0} Url={1} Error={2}" -f $Method, $Url, $_.Exception.Message) "ERROR"
    }
    return $null
  }
}

# Get Intune MDM device certificate and IDs from local machine store
function Get-IntuneMDMCertAndIDs {
  try {
    $deviceId = $null
    $accountId = $null
    $tenantId = $null
    $mdmOid = '1.2.840.113556.5.6'
    $issuer = 'Microsoft Intune MDM Device CA'
    
    Write-Log "Searching for Intune MDM device certificate..." "INFO"

    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("My", "LocalMachine")
    $store.Open('ReadOnly')
    $selectedCert = $store.Certificates | Where-Object {
      ($_.Issuer -like "*$issuer*") -and ($_.Extensions | Where-Object { $_.Oid.Value -eq $mdmOid }).Count -gt 0
    } | Sort-Object NotAfter -Descending | Select-Object -First 1
    $store.Close()

    if (-not $selectedCert) {
      Write-Log "No valid Intune MDM certificate found in LocalMachine\My." "WARNING"
      return $null
    }

    if ($selectedCert.Subject -notmatch '^CN=([\da-fA-F-]{36})') {
      throw "Could not parse DeviceId from certificate subject."
    }

    $deviceId = [guid]$Matches[1]

    foreach ($ext in $selectedCert.Extensions) {
      if ($ext.Oid.Value -eq $mdmOid) {
        $bytes = $null
        if ($ext.RawData.Length -eq 16) {
          $bytes = $ext.RawData
        } elseif ($ext.RawData.Length -eq 18 -and $ext.RawData[0] -eq 4 -and $ext.RawData[1] -eq 16) {
          $bytes = $ext.RawData[2..17]
        }
        if ($bytes) {
          $accountId = [guid][byte[]]$bytes
        }
        break
      }
    }

    Write-Log "Using Intune MDM certificate: $($selectedCert.Subject)" "INFO"
    Write-Log "Extracted DeviceId from certificate: $deviceId" "INFO"
    if ($accountId) { Write-Log "Extracted AccountId from certificate extension: $accountId" "INFO" }
    
    return [PSCustomObject]@{
      Certificate = $selectedCert
      Thumbprint  = $selectedCert.Thumbprint
      DeviceId    = $deviceId
      AccountId   = $accountId
      TenantId    = $tenantId
      Subject     = $selectedCert.Subject
      Issuer      = $selectedCert.Issuer
    }
  } catch {
    Write-Log "Error retrieving Intune device cert/IDs: $_" "ERROR"
    return $null
  }
}

# Discover regional Intune backend URLs from registry (standalone downloader parity)
function Get-IntuneLocationServiceUrls {
  try {
    $urls = @()
    $key = "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts"
    if (Test-Path $key) {
      foreach ($sub in Get-ChildItem $key) {
        $addrPath = "$($sub.PSPath)\Protected\AddrInfo"
        try {
          $addr = Get-ItemProperty -Path $addrPath -Name Addr -ErrorAction Stop
          if ($addr.Addr -and $addr.Addr -notlike "*checkin.dm.microsoft.com*") {
            $uri = [uri]$addr.Addr
            $fqdn = "$($uri.Scheme)://$($uri.Host)"
            if ($urls -notcontains $fqdn) {
              $urls += $fqdn
            }
          }
        } catch {
          continue
        }
      }
    }

    # Some devices report r.manage.microsoft.com, but the plain manage.microsoft.com host may be the one that responds.
    if ($urls -contains "https://r.manage.microsoft.com" -and ($urls -notcontains "https://manage.microsoft.com")) {
      $urls += "https://manage.microsoft.com"
    }

    if (-not $urls) {
      $urls = @("https://manage.microsoft.com")
      Write-Log "No registry URLs found, using default: $($urls[0])" "INFO"
    } else {
      Write-Log "Using LocationService URLs: $($urls -join ', ')" "INFO"
    }

    return $urls
  } catch {
    Write-Log "Error getting Intune location service URLs: $_" "WARNING"
    return @("https://manage.microsoft.com", "https://r.manage.microsoft.com")
  }
}

# Query Location Service to discover SideCarGateway endpoint (standalone downloader parity)
function Query-LocationService {
  param (
    [string[]]$LocationServiceUrls,
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$Cert
  )

  $discoPath = "/RestUserAuthLocationService/RestUserAuthLocationService/Certificate/ServiceAddresses"
  foreach ($fqdn in $LocationServiceUrls) {
    $url = "$fqdn$discoPath"
    Write-Log "Querying discovery endpoint: $url" "INFO"
    try {
      $req = [System.Net.HttpWebRequest]::Create($url)
      $req.Method = "GET"
      $null = $req.ClientCertificates.Add($Cert)
      $req.Timeout = 30000
      $req.Headers.Add("client-request-id", ([guid]::NewGuid()).Guid)
      [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
      $resp = $req.GetResponse()
      $reader = New-Object IO.StreamReader $resp.GetResponseStream()
      $json = $reader.ReadToEnd()
      $reader.Close()
      $resp.Close()
      Write-Log "Discovery response JSON received." "INFO"
      $result = $json | ConvertFrom-Json
      foreach ($entry in $result) {
        if ($entry.IsPrimary -eq $true) {
          $svc = $entry.Services | Where-Object { $_.ServiceName -eq "SideCarGatewayService" } | Select-Object -First 1
          if ($svc -and $svc.Url -is [string] -and $svc.Url.Trim()) {
            $cleanUrl = ([string]$svc.Url).Trim()
            Write-Log "Found SideCarGatewayService URL: $cleanUrl" "INFO"
            return $cleanUrl
          }
        }
      }
    } catch {
      $msg = $_.Exception.Message
      $respBody = $null
      try {
        if ($_.Exception.Response) {
          $stream = $_.Exception.Response.GetResponseStream()
          if ($stream) {
            $reader = New-Object IO.StreamReader $stream
            $respBody = $reader.ReadToEnd()
            $reader.Close()
          }
        }
      } catch { }

      if (-not $respBody) { $respBody = "<no response body>" }
      Write-Log ("Discovery request failed for {0}: {1} Body={2}" -f $fqdn, $msg, $respBody) "WARNING"
      if ($msg -match '(?i)ssl|tls') { throw }
    }
  }

  Write-Log "No valid SideCarGatewayService URL could be discovered. Returning empty string." "WARNING"
  return [string]::Empty
}

# Discover SideCarGateway endpoint using device certificate
function Discover-SideCarGatewayEndpoint {
  param(
    [string]$TenantId,
    [string]$DeviceId,
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$Cert
  )

  try {
    $urls = Get-IntuneLocationServiceUrls
    $endpoint = Query-LocationService -LocationServiceUrls $urls -Cert $Cert
    if ($endpoint -isnot [string]) { $endpoint = [string]$endpoint }
    $endpoint = $endpoint.Trim() -replace '^\s*0\s*', ''
    if ($endpoint -and $endpoint.StartsWith("https://")) {
      return $endpoint
    }

    return $null
  } catch {
    Write-Log "SideCarGateway discovery error: $_" "ERROR"
    return $null
  }
}

function Get-IntuneManagementExtensionVersion {
  try {
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    $ime = Get-ChildItem $regPath | 
           Where-Object { (Get-ItemProperty $_.PSPath).DisplayName -match "Intune Management Extension" } |
           Select-Object -First 1
    
    if ($ime) {
      return (Get-ItemProperty $ime.PSPath).DisplayVersion
    }
    return $null
  } catch {
    return $null
  }
}

# Decompress GZIP payload with 4-byte length prefix
function Decompress-IntuneSidecarPayload {
  param(
    [string]$CompressedBase64
  )
  
  try {
    $bytes = [Convert]::FromBase64String($CompressedBase64)
    # First 4 bytes = length, rest is GZIP
    $lengthBytes = $bytes[0..3]
    if ([BitConverter]::IsLittleEndian) { [Array]::Reverse($lengthBytes) }
    $length = [BitConverter]::ToInt32($lengthBytes, 0)
    
    $gzipData = $bytes[4..($bytes.Count - 1)]
    $ms = New-Object System.IO.MemoryStream -ArgumentList @(,$gzipData)
    $gz = New-Object System.IO.Compression.GzipStream($ms, [System.IO.Compression.CompressionMode]::Decompress)
    $output = New-Object System.IO.MemoryStream
    $gz.CopyTo($output)
    $decompressed = $output.ToArray()
    $gz.Dispose()
    $ms.Dispose()
    $output.Dispose()
    
    return [System.Text.Encoding]::UTF8.GetString($decompressed)
  } catch {
    Write-Log "Decompression error: $_" "ERROR"
    return $null
  }
}

function ConvertFrom-Base64Url {
  param(
    [string]$InputString
  )

  if ([string]::IsNullOrWhiteSpace($InputString)) { return $null }

  try {
    $padded = $InputString.Replace('-', '+').Replace('_', '/')
    switch ($padded.Length % 4) {
      2 { $padded += '==' }
      3 { $padded += '=' }
      default { }
    }
    return [Convert]::FromBase64String($padded)
  } catch {
    return $null
  }
}

function Get-JwtPayloadObject {
  param(
    [string]$Token
  )

  try {
    if ([string]::IsNullOrWhiteSpace($Token)) { return $null }
    $parts = $Token.Split('.')
    if ($parts.Count -lt 2) { return $null }

    $payloadBytes = ConvertFrom-Base64Url -InputString $parts[1]
    if (-not $payloadBytes) { return $null }

    $payloadJson = [System.Text.Encoding]::UTF8.GetString($payloadBytes)
    if ([string]::IsNullOrWhiteSpace($payloadJson)) { return $null }

    return ($payloadJson | ConvertFrom-Json)
  } catch {
    return $null
  }
}

function Get-JwtExpiryUtc {
  param(
    [string]$Token
  )

  try {
    $payload = Get-JwtPayloadObject -Token $Token
    if (-not $payload -or -not $payload.exp) { return $null }

    $epoch = [DateTimeOffset]::FromUnixTimeSeconds([Int64]$payload.exp)
    return $epoch.UtcDateTime
  } catch {
    return $null
  }
}

# Get latest bearer token from local token cache (for device context)
function Get-LatestIntuneBearerToken {
  try {
    $clientId = "fc0f3af4-6835-4174-b806-f7db311fd2f3"

    $cachePaths = @(
      "$env:LOCALAPPDATA\Microsoft\TokenBroker\Cache",
      "$env:LOCALAPPDATA\Microsoft\IdentityCache",
      "$env:WINDIR\System32\config\systemprofile\AppData\Local\Microsoft\TokenBroker\Cache",
      "$env:WINDIR\ServiceProfiles\LocalService\AppData\Local\Microsoft\TokenBroker\Cache",
      "$env:WINDIR\ServiceProfiles\NetworkService\AppData\Local\Microsoft\TokenBroker\Cache"
    ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

    if ($cachePaths.Count -eq 0) {
      Write-Log "No TokenBroker cache paths were found." "WARNING"
      return $null
    }

    $cacheFiles = @(
      foreach ($path in $cachePaths) {
        Get-ChildItem $path -File -Recurse -ErrorAction SilentlyContinue |
          Where-Object { $_.Extension -in @('.tbres', '.tbr', '.cache', '.dat') }
      }
    ) | Sort-Object LastWriteTime -Descending

    if ($cacheFiles.Count -eq 0) {
      Write-Log "No token cache files found in TokenBroker paths." "WARNING"
      return $null
    }

    $jwtRegex = [regex]'eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+'
    $nowUtc = (Get-Date).ToUniversalTime()
    $bestToken = $null
    $bestScore = -1
    $bestExpiry = [DateTime]::MinValue

    foreach ($file in $cacheFiles) {
      try {
        $rawBytes = [System.IO.File]::ReadAllBytes($file.FullName)
        if (-not $rawBytes -or $rawBytes.Length -eq 0) { continue }

        $textCandidates = @(
          [System.Text.Encoding]::Unicode.GetString($rawBytes),
          [System.Text.Encoding]::UTF8.GetString($rawBytes),
          [System.Text.Encoding]::ASCII.GetString($rawBytes)
        ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

        $responseBytesValue = $null
        foreach ($candidate in $textCandidates) {
          try {
            $trimmed = $candidate.Trim([char]0)
            $json = $trimmed | ConvertFrom-Json -ErrorAction Stop
            $responseBytesValue = $json.TBDataStoreObject.ObjectData.SystemDefinedProperties.ResponseBytes.Value
            if ($responseBytesValue) { break }
          } catch {
            continue
          }
        }

        if ($responseBytesValue) {
          try {
            $encBytes = [Convert]::FromBase64String([string]$responseBytesValue)
            $scopeCandidates = @(
              [System.Security.Cryptography.DataProtectionScope]::CurrentUser,
              [System.Security.Cryptography.DataProtectionScope]::LocalMachine
            )
            foreach ($scope in $scopeCandidates) {
              try {
                $plain = [System.Security.Cryptography.ProtectedData]::Unprotect($encBytes, $null, $scope)
                if ($plain -and $plain.Length -gt 0) {
                  $textCandidates += [System.Text.Encoding]::UTF8.GetString($plain)
                  $textCandidates += [System.Text.Encoding]::Unicode.GetString($plain)
                }
              } catch {
                continue
              }
            }
          } catch {
            continue
          }
        }

        foreach ($text in ($textCandidates | Select-Object -Unique)) {
          $jwtMatches = $jwtRegex.Matches($text)
          if (-not $jwtMatches -or $jwtMatches.Count -eq 0) { continue }

          $hasClientIdHint = $text -match [regex]::Escape($clientId)

          foreach ($m in $jwtMatches) {
            $token = [string]$m.Value
            if ([string]::IsNullOrWhiteSpace($token)) { continue }

            $expiryUtc = Get-JwtExpiryUtc -Token $token
            if ($expiryUtc -and $expiryUtc -le $nowUtc.AddMinutes(5)) { continue }

            $score = 0
            if ($hasClientIdHint) { $score += 100 }

            $payload = Get-JwtPayloadObject -Token $token
            if ($payload) {
              if (($payload.appid -eq $clientId) -or ($payload.azp -eq $clientId)) { $score += 100 }
              if (($payload.aud -as [string]) -match '(?i)manage|device|mdm|sidecar') { $score += 10 }
            }

            if (-not $expiryUtc) { $expiryUtc = $nowUtc.AddYears(1) }
            if ($score -gt $bestScore -or ($score -eq $bestScore -and $expiryUtc -gt $bestExpiry)) {
              $bestScore = $score
              $bestExpiry = $expiryUtc
              $bestToken = $token
            }
          }
        }
      } catch {
        continue
      }
    }

    if ($bestToken) {
      Write-Log "Bearer token acquired from local cache." "INFO"
      return $bestToken
    }

    Write-Log "No valid bearer token found in cache." "WARNING"
    return $null
  } catch {
    Write-Log "Error retrieving bearer token: $_" "ERROR"
    return $null
  }
}

function Get-DecryptionInfoFromResponse {
  param(
    [Parameter(Mandatory)]
    [object]$ResponseObject
  )

  $respPayload = $ResponseObject.ResponsePayload
  if ($respPayload -is [string]) {
    $respPayload = $respPayload | ConvertFrom-Json
  }

  $decryptInfoXml = $respPayload.DecryptInfo
  if (-not $decryptInfoXml) {
    Write-Warning "No DecryptInfo in response."
    return $null
  }

  [xml]$decryptInfo = $decryptInfoXml
  $encryptedContent = $decryptInfo.EncryptedMessage.EncryptedContent
  if (-not $encryptedContent) {
    Write-Warning "No EncryptedContent found in DecryptInfo XML."
    return $null
  }

  [Reflection.Assembly]::LoadWithPartialName("System.Security") | Out-Null
  [Reflection.Assembly]::LoadWithPartialName("System.Security.Cryptography.Pkcs") | Out-Null
  $bytes = [Convert]::FromBase64String($encryptedContent)
  $cms = New-Object System.Security.Cryptography.Pkcs.EnvelopedCms
  $cms.Decode($bytes)
  $cms.Decrypt()
  $utf8Json = [System.Text.Encoding]::UTF8.GetString($cms.ContentInfo.Content)
  return ($utf8Json | ConvertFrom-Json)
}

function Get-UploadLocationAndDownload {
  param (
    [Parameter(Mandatory)]
    [object]$Response,
    [Parameter(Mandatory)]
    [string]$OutputPath,
    [int]$MaxRetries = 3,
    [int]$DelaySeconds = 5
  )

  if ($Response -is [string]) {
    $ResponseObj = $Response | ConvertFrom-Json
  } else {
    $ResponseObj = $Response
  }

  if (-not $ResponseObj.ResponsePayload) {
    Write-Log "No ResponsePayload in response!" "ERROR"
    return $null
  }

  $payload = $ResponseObj.ResponsePayload | ConvertFrom-Json
  if (-not $payload.ContentInfo) {
    Write-Log "No ContentInfo in payload!" "ERROR"
    return $null
  }

  $contentInfo = $payload.ContentInfo | ConvertFrom-Json
  $uploadUrl = [string]$contentInfo.UploadLocation
  if ([string]::IsNullOrWhiteSpace($uploadUrl)) {
    Write-Log "No UploadLocation found." "ERROR"
    return $null
  }

  $urlVariants = @($uploadUrl)
  try {
    $uri = [Uri]$uploadUrl
    if ($uri.Scheme -eq 'http' -and $uri.Host -match '(?i)\.manage\.microsoft\.com$') {
      $secureUrl = $uploadUrl -replace '^http://', 'https://'
      if ($secureUrl -ne $uploadUrl) {
        $urlVariants = @($secureUrl, $uploadUrl)
        Write-Log "UploadLocation provided over HTTP; trying HTTPS variant first." "INFO"
      }
    }
  } catch { }

  Write-Log "Found UploadLocation: $uploadUrl" "INFO"
  Write-Log "Downloading to: $OutputPath" "INFO"

  foreach ($candidateUrl in $urlVariants) {
    $attempt = 1
    while ($attempt -le $MaxRetries) {
      try {
        if (Test-Path $OutputPath) { Remove-Item $OutputPath -Force -ErrorAction SilentlyContinue }
        Start-BitsTransfer -Source $candidateUrl -Destination $OutputPath -ErrorAction Stop
        if ((Test-Path $OutputPath) -and ((Get-Item $OutputPath).Length -gt 0)) {
          Write-Log "Download complete via BITS on attempt $attempt." "INFO"
          return $OutputPath
        }
        throw "BITS completed but output file was empty."
      } catch {
        Write-Log "BITS attempt $attempt failed for $candidateUrl : $($_.Exception.Message)" "WARNING"
        if ($attempt -lt $MaxRetries) { Start-Sleep -Seconds $DelaySeconds }
      }
      $attempt++
    }

    try {
      if (Test-Path $OutputPath) { Remove-Item $OutputPath -Force -ErrorAction SilentlyContinue }
      [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
      Invoke-WebRequest -Uri $candidateUrl -OutFile $OutputPath -UseBasicParsing -ErrorAction Stop
      if ((Test-Path $OutputPath) -and ((Get-Item $OutputPath).Length -gt 0)) {
        Write-Log "Download complete via Invoke-WebRequest." "INFO"
        return $OutputPath
      }
      throw "Invoke-WebRequest completed but output file was empty."
    } catch {
      Write-Log "Invoke-WebRequest failed for $candidateUrl : $($_.Exception.Message)" "WARNING"
    }

    try {
      if (Test-Path $OutputPath) { Remove-Item $OutputPath -Force -ErrorAction SilentlyContinue }
      Write-Log "Falling back to curl.exe for $candidateUrl." "INFO"
      $curlOutput = & curl.exe -L --fail --show-error --output $OutputPath $candidateUrl 2>&1 | Out-String
      if ((Test-Path $OutputPath) -and ((Get-Item $OutputPath).Length -gt 0)) {
        Write-Log "Download complete via curl.exe." "INFO"
        return $OutputPath
      }
      if ($curlOutput) {
        $trimmed = $curlOutput.Trim()
        if ($trimmed) { Write-Log "curl.exe output: $trimmed" "WARNING" }
      }
      Write-Log "curl.exe failed to download a non-empty file." "WARNING"
    } catch {
      Write-Log "curl.exe failed for $candidateUrl : $($_.Exception.Message)" "WARNING"
    }
  }

  Write-Log "All download methods failed. No file downloaded." "ERROR"
  return $null
}

function Decrypt-IntuneWinFile {
  param(
    [Parameter(Mandatory)] [string]$IntuneWinFile,
    [Parameter(Mandatory)] [string]$OutputZipFile,
    [Parameter(Mandatory)] [string]$Base64Key,
    [Parameter(Mandatory)] [string]$Base64IV
  )

  Add-Type -AssemblyName System.Security
  [Reflection.Assembly]::LoadWithPartialName("System.Security.Cryptography") | Out-Null

  $key = [Convert]::FromBase64String($Base64Key)
  $iv  = [Convert]::FromBase64String($Base64IV)

  $inStream  = [System.IO.File]::Open($IntuneWinFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
  $outStream = [System.IO.File]::Open($OutputZipFile, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)

  try {
    $inStream.Seek(48, [System.IO.SeekOrigin]::Begin) | Out-Null

    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $key
    $aes.IV  = $iv
    $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7

    $decryptor = $aes.CreateDecryptor()
    $cryptoStream = New-Object System.Security.Cryptography.CryptoStream($outStream, $decryptor, [System.Security.Cryptography.CryptoStreamMode]::Write)

    $buffer = New-Object byte[] 2097152
    while (($read = $inStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
      $cryptoStream.Write($buffer, 0, $read)
    }

    $cryptoStream.FlushFinalBlock()
    Write-Log "Decryption complete: $OutputZipFile" "INFO"
  }
  finally {
    if ($cryptoStream) { $cryptoStream.Close() }
    if ($outStream) { $outStream.Close() }
    if ($inStream) { $inStream.Close() }
    if ($aes) { $aes.Dispose() }
  }
}

function Send-GetContentInfoRequest {
  param (
    [string]$endpoint,
    [string]$accountId,
    [string]$deviceId,
    [string]$bearerToken,
    [System.Security.Cryptography.X509Certificates.X509Certificate2]$cert,
    [string]$certBlob,
    [string]$applicationId,
    [string]$applicationVersion
  )

  $imeVersion = Get-IntuneManagementExtensionVersion
  if (-not $imeVersion) {
    $imeVersion = "1.91.102.0"
    Write-Log "IME version not found in registry, falling back to: $imeVersion" "INFO"
  } else {
    Write-Log "Detected IME version: $imeVersion" "INFO"
  }

  $sessionId = [guid]::NewGuid().Guid
  $url = "$endpoint/SideCarGatewaySessions('$sessionId')?api-version=1.5"
  Write-Log "Sending PUT to $url (GetContentInfo) for AppId [$applicationId]" "INFO"

  $reqPayloadObj = @{
    ContentInfo        = $null
    Intent             = 1
    CertificateBlob    = $certBlob
    DecryptInfo        = $null
    UploadLocation     = $null
    ApplicationVersion = $applicationVersion
    ApplicationId      = $applicationId
  }
  $reqPayload = $reqPayloadObj | ConvertTo-Json -Compress -Depth 6
  $body = @{
    Key                 = $sessionId
    SessionId           = $sessionId
    RequestContentType   = "GetContentInfo"
    RequestPayload       = $reqPayload
    ResponseContentType  = $null
    ClientInfo          = @{
      DeviceName = $env:COMPUTERNAME
      OperatingSystemVersion = (Get-CimInstance Win32_OperatingSystem).Version
      SideCarAgentVersion = $imeVersion
    } | ConvertTo-Json -Compress
    ResponsePayload      = $null
    CheckinReasonPayload = '{"NotificationID":"00000000-0000-0000-0000-000000000000","NotificationIntent":""}'
  }
  $bodyJson = $body | ConvertTo-Json -Compress -Depth 10
  $headers = @{
    "Authorization" = "Bearer $bearerToken"
    "client-request-id" = ([guid]::NewGuid()).Guid
    "AccountId" = $accountId
    "DeviceId" = $deviceId
    "Prefer" = "return-content"
    "Request-Attempt-Count" = "1"
    "Scenario-Type" = "Windows-GetContentInfo"
  }

  return Invoke-MtlsRestRequest -Url $url -Method "PUT" -Body $bodyJson -Cert $cert -Headers $headers
}

# Download and decrypt Win32 app via device MTLS certificate (Intune SideCarGateway)
function Get-IntuneWinViaDeviceCert {
  param(
    [string]$AppQuery,
    [string]$DestinationFolder
  )
  
  Write-Log "Starting Intune app download via device MDM certificate..." "INFO"
  
  # Get device cert and IDs
  $devInfo = Get-IntuneMDMCertAndIDs
  if (-not $devInfo) {
    throw "Failed to retrieve device MDM certificate. Ensure device is Intune-enrolled with certificate installed."
  }
  
  # Get bearer token
  $token = Get-LatestIntuneBearerToken
  if (-not $token) {
    throw "Failed to retrieve bearer token. Ensure Intune Management Extension is active."
  }
  
  # Log certificate info for diagnostics
  Write-Log "Using certificate: Subject=$($devInfo.Subject), Thumbprint=$($devInfo.Thumbprint)" "INFO"
  
  Write-Log "Enrollment: DeviceId=$($devInfo.DeviceId), TenantId=$($devInfo.TenantId), AccountId=$($devInfo.AccountId)" "INFO"
  # Discover SideCarGateway endpoint using device cert and tenant ID
  $gateway = Discover-SideCarGatewayEndpoint -TenantId $devInfo.TenantId -DeviceId $devInfo.DeviceId -Cert $devInfo.Certificate
  if (-not $gateway) {
    throw "Failed to discover SideCarGateway endpoint. Device may not have proper enrollment configuration or may not be assigned any apps."
  }

  Write-Log "Using SideCarGateway: $gateway" "INFO"
  
  # Query available apps
  $sessionId = [guid]::NewGuid().Guid
  $url = "{0}/SideCarGatewaySessions('{1}')?api-version=1.5" -f ($gateway.TrimEnd('/')), $sessionId
  
  $imeVersion = Get-IntuneManagementExtensionVersion
  if (-not $imeVersion) { $imeVersion = "1.91.102.0" }
  
  $clientInfo = @{
    DeviceName = $env:COMPUTERNAME
    OperatingSystemVersion = (Get-CimInstance Win32_OperatingSystem).Version
    SideCarAgentVersion = $imeVersion
  } | ConvertTo-Json -Compress
  
  $accountCandidates = @()
  if ($devInfo.AccountId) { $accountCandidates += [string]$devInfo.AccountId }
  if ($devInfo.TenantId -and -not ($accountCandidates -contains [string]$devInfo.TenantId)) { $accountCandidates += [string]$devInfo.TenantId }
  if ($devInfo.DeviceId -and -not ($accountCandidates -contains [string]$devInfo.DeviceId)) { $accountCandidates += [string]$devInfo.DeviceId }
  if ($accountCandidates.Count -eq 0) { $accountCandidates += "unknown" }

  $requestVariants = @(
    @{ RequestContentType = "GetAvailableApp"; ScenarioType = "Windows-GetAvailableApp"; RequestPayload = "[]" },
    @{ RequestContentType = "RequestApplication"; ScenarioType = "Windows-RequestApplication"; RequestPayload = "[]" },
    @{ RequestContentType = "GetSelectedApp"; ScenarioType = "Windows-GetSelectedApp"; RequestPayload = "[]" }
  )

  Write-Log ("Submitting SideCar session request: {0}" -f $url) "INFO"

  $response = $null
  $hadEmptyResponse = $false
  $matchedApp = $null
  $matchedBucket = $null
  foreach ($variant in $requestVariants) {
    foreach ($candidateAccountId in $accountCandidates) {
      $body = @{
        Key = $sessionId
        SessionId = $sessionId
        RequestContentType = $variant.RequestContentType
        RequestPayload = $variant.RequestPayload
        ResponseContentType = $null
        ClientInfo = $clientInfo
        ResponsePayload = $null
        CheckinReasonPayload = '{"NotificationID":"00000000-0000-0000-0000-000000000000","NotificationIntent":""}'
      } | ConvertTo-Json -Compress

      $headers = @{
        "Authorization" = "Bearer $token"
        "client-request-id" = ([guid]::NewGuid()).Guid
        "AccountId" = $candidateAccountId
        "DeviceId" = if ($devInfo.DeviceId) { $devInfo.DeviceId } else { "unknown" }
        "Content-Type" = "application/json; charset=utf-8"
        "Prefer" = "return-content"
        "Request-Attempt-Count" = "1"
        "Scenario-Type" = $variant.ScenarioType
        "Accept" = "application/json"
        "User-Agent" = "IntuneManagementExtension/$imeVersion"
      }

      Write-Log ("Trying SideCar session: RequestType={0}, AccountId={1}" -f $variant.RequestContentType, $candidateAccountId) "INFO"
      $response = Invoke-MtlsRestRequest -Url $url -Method "PUT" -Body $body -Cert $devInfo.Certificate -Headers $headers
      if ($null -ne $response -and [string]::IsNullOrWhiteSpace([string]$response)) {
        $hadEmptyResponse = $true
        Write-Log "SideCar endpoint returned success with empty body; trying next request variant." "WARNING"
        continue
      }

      if (-not $response) { continue }

      try {
        $result = $response | ConvertFrom-Json
      } catch {
        Write-Log ("Failed to parse SideCar response for {0}: {1}" -f $variant.RequestContentType, $_.Exception.Message) "WARNING"
        continue
      }

      $payload = $result.ResponsePayload
      if (-not $payload) {
        Write-Log ("No ResponsePayload present for {0}; trying next variant." -f $variant.RequestContentType) "WARNING"
        continue
      }

      try {
        $decoded = Decompress-IntuneSidecarPayload -CompressedBase64 $payload
        $apps = $decoded | ConvertFrom-Json
      } catch {
        Write-Log ("Failed to decode SideCar payload for {0}: {1}" -f $variant.RequestContentType, $_.Exception.Message) "WARNING"
        continue
      }

      $matchedApp = $apps | Where-Object {
        $_.id -eq $AppQuery -or $_.displayName -like "*$AppQuery*"
      } | Select-Object -First 1

      if ($matchedApp) {
        $matchedBucket = $variant.RequestContentType
        Write-Log ("Found app in {0}: {1} (ID: {2})" -f $matchedBucket, $matchedApp.displayName, $matchedApp.id) "INFO"
        break
      }

      Write-Log ("AppId [{0}] not present in {1}; trying next SideCar view." -f $AppQuery, $variant.RequestContentType) "INFO"
    }

    if ($matchedApp) { break }
  }

  if (-not $matchedApp) {
    if ($hadEmptyResponse) {
      Write-Log "SideCar responded but did not provide payload. This can indicate no app assignments for this device context." "WARNING"
    }
    Write-Log "SideCarGateway did not return app list. This may occur if device is not fully provisioned for app management." "WARNING"
    Write-Log "Suggestion: Use Graph API pull instead (usually more reliable). Device cert method requires full MDM enrollment and app assignment policies." "INFO"
    throw "App '$AppQuery' not found in available, required, or selected apps."
  }

  $applicationVersion = $null
  if ($matchedApp.PSObject.Properties.Match('version').Count -gt 0 -and $matchedApp.version) {
    $applicationVersion = [string]$matchedApp.version
  } elseif ($matchedApp.PSObject.Properties.Match('appVersion').Count -gt 0 -and $matchedApp.appVersion) {
    $applicationVersion = [string]$matchedApp.appVersion
  }
  if (-not $applicationVersion) {
    $applicationVersion = "1"
  }

  $safeName = if ($matchedApp.displayName) { ($matchedApp.displayName -replace '[\\/:*?"<>|]', '_').Trim() } else { $matchedApp.id }
  $certBytes = $devInfo.Certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
  $certBlob = [Convert]::ToBase64String($certBytes)

  $contentResponse = Send-GetContentInfoRequest -endpoint $gateway -accountId $devInfo.AccountId -deviceId $devInfo.DeviceId `
    -bearerToken $token -cert $devInfo.Certificate -certBlob $certBlob `
    -applicationId $matchedApp.id -applicationVersion $applicationVersion

  if (-not $contentResponse) {
    throw "No response from server for AppId [$($matchedApp.id)]."
  }

  try {
    $json = $contentResponse | ConvertFrom-Json
  } catch {
    throw "Failed to parse content response as JSON for AppId [$($matchedApp.id)]: $($_.Exception.Message)"
  }

  if (-not $json.ResponsePayload) {
    throw "No ResponsePayload in response for AppId [$($matchedApp.id)]."
  }

  $payload = $json.ResponsePayload | ConvertFrom-Json
  if (-not $payload.ContentInfo) {
    throw "No ContentInfo found in payload for AppId [$($matchedApp.id)]."
  }

  Write-Log "Successfully found ContentInfo for AppId [$($matchedApp.id)]." "INFO"

  $decryptionInfo = Get-DecryptionInfoFromResponse -ResponseObject $json
  if (-not $decryptionInfo) {
    throw "No decryption info found in response for AppId [$($matchedApp.id)]."
  }

  if (-not (Test-Path $DestinationFolder)) {
    New-Item -ItemType Directory -Path $DestinationFolder -Force | Out-Null
  }

  $binPath = Join-Path $DestinationFolder "$safeName.intunewin.bin"
  $zipPath = Join-Path $DestinationFolder "$safeName.decoded.zip"

  $downloadedFile = Get-UploadLocationAndDownload -Response $json -OutputPath $binPath
  if (-not $downloadedFile) {
    throw "No file downloaded for AppId [$($matchedApp.id)]."
  }

  Decrypt-IntuneWinFile -IntuneWinFile $downloadedFile -OutputZipFile $zipPath -Base64Key $decryptionInfo.EncryptionKey -Base64IV $decryptionInfo.IV

  return [pscustomobject]@{
    Id = $matchedApp.id
    DisplayName = $matchedApp.displayName
    Version = $applicationVersion
    DownloadedFile = $downloadedFile
    DecodedZip = $zipPath
  }
}
#endregion

#region -------------------- Async packaging (Runspace + polling) --------------------
function Start-PackagingAsync {
  param([Parameter(Mandatory)]$PkgInput)

  $rs = [runspacefactory]::CreateRunspace()
  $rs.ApartmentState = 'STA'
  $rs.ThreadOptions = 'ReuseThread'
  $rs.Open()

  $ps = [powershell]::Create()
  $ps.Runspace = $rs

  # Worker returns structured output (lines + exit code + output file guess)
  $null = $ps.AddScript({
    param($UtilPath, $SourceFolder, $SetupFile, $OutputFolder)

    $result = [ordered]@{
      Started     = (Get-Date).ToString("s")
      ExitCode    = $null
      StdOut      = ''
      StdErr      = ''
      OutputFiles = @()
      Args        = ''
    }

    try {
      $args = "-c `"$SourceFolder`" -s `"$SetupFile`" -o `"$OutputFolder`" -q"
      $result.Args = $args

      $psi = New-Object System.Diagnostics.ProcessStartInfo
      $psi.FileName = $UtilPath
      $psi.Arguments = $args
      $psi.UseShellExecute = $false
      $psi.RedirectStandardOutput = $true
      $psi.RedirectStandardError  = $true
      $psi.CreateNoWindow = $true

      $p = New-Object System.Diagnostics.Process
      $p.StartInfo = $psi

      if (-not $p.Start()) { throw "Failed to start IntuneWinAppUtil.exe." }
      $stdout = $p.StandardOutput.ReadToEnd()
      $stderr = $p.StandardError.ReadToEnd()
      $p.WaitForExit()

      $result.ExitCode = $p.ExitCode
      $result.StdOut = $stdout
      $result.StdErr = $stderr
    }
    catch {
      $result.ExitCode = -1
      $result.StdErr = $_.Exception.Message
    }

    try {
      $files = Get-ChildItem -LiteralPath $OutputFolder -Filter *.intunewin -ErrorAction SilentlyContinue |
               Sort-Object LastWriteTime -Descending |
               Select-Object -First 5 -ExpandProperty FullName
      if ($files) { $result.OutputFiles = @($files) }
    } catch {}

    [pscustomobject]$result
  }) | Out-Null
  $null = $ps.AddArgument($PkgInput.UtilPath)
  $null = $ps.AddArgument($PkgInput.SourceFolder)
  $null = $ps.AddArgument($PkgInput.SetupFile)
  $null = $ps.AddArgument($PkgInput.OutputFolder)

  $handle = $ps.BeginInvoke()

  $script:ActiveRunspace = $rs
  $script:AsyncPowerShell = $ps
  $script:AsyncResult = $handle
}

function Start-ExtractionAsync {
  param([Parameter(Mandatory)]$ExtractInput)

  $rs = [runspacefactory]::CreateRunspace()
  $rs.ApartmentState = 'STA'
  $rs.ThreadOptions = 'ReuseThread'
  $rs.Open()

  $ps = [powershell]::Create()
  $ps.Runspace = $rs

  $null = $ps.AddScript({
    param($IntuneWinFile, $DestinationFolder)

    $result = [ordered]@{
      Started     = (Get-Date).ToString("s")
      ExitCode    = 0
      StdOut      = ''
      StdErr      = ''
    }

    function Log { param($Msg) $result.StdOut += "$Msg`r`n" }

    function Repair-DecodedZip {
      param(
        [Parameter(Mandatory)] [string]$InputFile,
        [Parameter(Mandatory)] [string]$OutputFile
      )

      $bytes = [System.IO.File]::ReadAllBytes($InputFile)
      if ($bytes.Length -lt 22) { return $false }

      $pkStart = -1
      for ($i = 0; $i -le ($bytes.Length - 4); $i++) {
        if ($bytes[$i] -eq 0x50 -and $bytes[$i + 1] -eq 0x4B -and $bytes[$i + 2] -eq 0x03 -and $bytes[$i + 3] -eq 0x04) {
          $pkStart = $i
          break
        }
      }
      if ($pkStart -lt 0) { return $false }

      $eocd = -1
      for ($i = $bytes.Length - 22; $i -ge $pkStart; $i--) {
        if ($bytes[$i] -eq 0x50 -and $bytes[$i + 1] -eq 0x4B -and $bytes[$i + 2] -eq 0x05 -and $bytes[$i + 3] -eq 0x06) {
          $eocd = $i
          break
        }
      }
      if ($eocd -lt 0) { return $false }

      $commentLength = [BitConverter]::ToUInt16($bytes, $eocd + 20)
      $zipEnd = $eocd + 22 + $commentLength
      if ($zipEnd -gt $bytes.Length) { return $false }

      $zipLength = $zipEnd - $pkStart
      if ($zipLength -le 0) { return $false }

      $zipBytes = New-Object byte[] $zipLength
      [System.Array]::Copy($bytes, $pkStart, $zipBytes, 0, $zipLength)
      [System.IO.File]::WriteAllBytes($OutputFile, $zipBytes)
      return $true
    }

    try {
      Add-Type -AssemblyName System.IO.Compression.FileSystem
      Add-Type -AssemblyName System.Security

      $file = Get-Item -LiteralPath $IntuneWinFile
      $fileName = $file.Name
      $workDir = Join-Path $DestinationFolder ("Extract_" + [System.IO.Path]::GetFileNameWithoutExtension($fileName))
      
      Log "Extracting $($fileName) to $workDir..."
      
      if (-not (Test-Path $workDir)) { New-Item -ItemType Directory -Path $workDir -Force | Out-Null }
      
      # Step 1: Unzip outer
      $tempZipDir = Join-Path $workDir "_temp_outer"
      if (Test-Path $tempZipDir) { Remove-Item $tempZipDir -Recurse -Force }
      New-Item -ItemType Directory -Path $tempZipDir -Force | Out-Null
      
      [System.IO.Compression.ZipFile]::ExtractToDirectory($IntuneWinFile, $tempZipDir)
      
      # Step 2: Read detection.xml
      $xmlFile = Get-ChildItem -Path $tempZipDir -Filter "detection.xml" -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
      if (-not $xmlFile) {
        $topItems = Get-ChildItem -Path $tempZipDir -Force -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
        if ($topItems) {
          Log "detection.xml not found. Treating input as an already-decoded ZIP and extracting contents directly. Root items: $($topItems -join ', ')"
        } else {
          Log "detection.xml not found. Treating input as an already-decoded ZIP and extracting contents directly."
        }

        $finalDir = Join-Path $workDir "Content"
        if (Test-Path $finalDir) { Remove-Item $finalDir -Recurse -Force }
        [System.IO.Compression.ZipFile]::ExtractToDirectory($IntuneWinFile, $finalDir)
        Remove-Item $tempZipDir -Recurse -Force
        Log "Done. Content extracted to: $finalDir"
        $result.ExitCode = 0
        [pscustomobject]$result
        return
      }

      $xmlPath = $xmlFile.FullName
      Log "Using metadata: $xmlPath"

      [xml]$xml = Get-Content -LiteralPath $xmlPath -Raw
      $encInfo = $xml.ApplicationInfo.EncryptionInfo
      
      if (-not $encInfo) { throw "EncryptionInfo not found in detection.xml" }

      $expectedPayloadName = $xml.ApplicationInfo.FileName
      $expectedPayloadLeaf = $null
      if ($expectedPayloadName) {
        $normalizedExpectedPayloadName = ($expectedPayloadName -replace '/', '\\')
        $expectedPayloadLeaf = [System.IO.Path]::GetFileName($normalizedExpectedPayloadName)
      }

      $pkgFile = $null
      if ($expectedPayloadLeaf) {
        $pkgFile = Get-ChildItem -Path $tempZipDir -File -Recurse -ErrorAction SilentlyContinue |
          Where-Object { $_.Name -eq $expectedPayloadLeaf } |
          Select-Object -First 1
      }
      if (-not $pkgFile -and $expectedPayloadName) {
        $pkgFile = Get-ChildItem -Path $tempZipDir -Filter $expectedPayloadName -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
      }
      if (-not $pkgFile) {
        $pkgFile = Get-ChildItem -Path $tempZipDir -Filter "*.intunewin" -File -Recurse -ErrorAction SilentlyContinue |
          Sort-Object Length -Descending |
          Select-Object -First 1
      }
      if (-not $pkgFile) { throw "Encrypted payload (*.intunewin) not found inside package." }

      $pkgPath = $pkgFile.FullName
      Log "Using payload: $pkgPath"
      
      $keyBytes = [Convert]::FromBase64String($encInfo.EncryptionKey)
      $ivBytes  = [Convert]::FromBase64String($encInfo.InitializationVector)
      
      # Step 3: Decrypt
      Log "Decrypting payload..."
      
      $decodedPkg = Join-Path $workDir "IntunePackage_Decoded.zip"
      
      $aes = [System.Security.Cryptography.Aes]::Create()
      $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
      $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
      $aes.Key = $keyBytes
      $aes.IV = $ivBytes
      
      $fsIn = [System.IO.File]::OpenRead($pkgPath)
      $fsOut = [System.IO.File]::Create($decodedPkg)
      $transform = $aes.CreateDecryptor()
      
      # Use CryptoStream
      $cryptoStream = New-Object System.Security.Cryptography.CryptoStream($fsOut, $transform, [System.Security.Cryptography.CryptoStreamMode]::Write)
      
      $buffer = New-Object byte[] 81920
      while (($count = $fsIn.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $cryptoStream.Write($buffer, 0, $count)
      }
      
      if ($cryptoStream.CanWrite) { $cryptoStream.FlushFinalBlock() }
      $cryptoStream.Close()
      $fsOut.Close()
      $fsIn.Close()
      
      # Step 4: Unzip decoded
      Log "Unzipping payload..."
      $finalDir = Join-Path $workDir "Content"
      if (Test-Path $finalDir) { Remove-Item $finalDir -Recurse -Force }
      
      # The decrypted file is a ZIP, but sometimes it doesn't have a specific header if it was just raw bytes.
      # But IntuneWinUtil usually zips source first.

      try {
        [System.IO.Compression.ZipFile]::ExtractToDirectory($decodedPkg, $finalDir)
      }
      catch {
        Log "Primary unzip failed: $($_.Exception.Message)"
        $repairedPkg = Join-Path $workDir "IntunePackage_Decoded_repaired.zip"
        if (Repair-DecodedZip -InputFile $decodedPkg -OutputFile $repairedPkg) {
          Log "Retrying unzip with repaired ZIP boundaries..."
          [System.IO.Compression.ZipFile]::ExtractToDirectory($repairedPkg, $finalDir)
          if (Test-Path $repairedPkg) { Remove-Item $repairedPkg -Force }
        }
        else {
          throw
        }
      }
      
      # Cleanup
      Remove-Item $tempZipDir -Recurse -Force
      Remove-Item $decodedPkg -Force
      
      Log "Done. Content extracted to: $finalDir"
    }
    catch {
      $result.ExitCode = -1
      $result.StdErr = $_.Exception.Message
      if ($_.Exception.InnerException) { $result.StdErr += "`r`nInner: " + $_.Exception.InnerException.Message }
    }
    
    [pscustomobject]$result
  }) | Out-Null

  $null = $ps.AddArgument($ExtractInput.IntuneWinFile)
  $null = $ps.AddArgument($ExtractInput.DestinationFolder)

  $handle = $ps.BeginInvoke()

  $script:ActiveRunspace = $rs
  $script:AsyncPowerShell = $ps
  $script:AsyncResult = $handle
}

function Start-ToolUpdateAsync {
  param($DestPath)

  $rs = [runspacefactory]::CreateRunspace()
  $rs.ApartmentState = 'STA' # WebClient/WebRequest fine in STA
  $rs.ThreadOptions = 'ReuseThread'
  $rs.Open()

  $ps = [powershell]::Create()
  $ps.Runspace = $rs

  $null = $ps.AddScript({
    param($TargetFile)
    $result = [ordered]@{
      Started     = (Get-Date).ToString("s")
      ExitCode    = 0
      StdOut      = ''
      StdErr      = ''
    }
    
    try {
       # Use global security protocol just in case
       [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
       
       $result.StdOut += "Checking for latest release...`r`n"
       $api = "https://api.github.com/repos/microsoft/Microsoft-Win32-Content-Prep-Tool/releases/latest"
       $json = Invoke-RestMethod $api -UseBasicParsing
       
       # Check for direct asset (exe) or fallback to zipball
       $dlUrl = $null
       
       $asset = $json.assets | Where-Object { $_.name -like '*IntuneWinAppUtil.exe*' } | Select-Object -First 1
       if ($asset) {
          $dlUrl = $asset.browser_download_url
          $result.StdOut += "Found executable asset: $($asset.name)`r`n"
       } else {
          $dlUrl = $json.zipball_url
          if (-not $dlUrl) { throw "No asset or zipball found in the latest GitHub release." }
          $result.StdOut += "Exe not found in assets. Falling back to source zip: $dlUrl`r`n"
       }
       
       $result.StdOut += "Found version: $($json.tag_name)`r`n"
       
       if ($dlUrl -match '\.zip$|zipball') {
          $tempZip = [System.IO.Path]::GetTempFileName() + ".zip"
          $result.StdOut += "Downloading zip to: $tempZip`r`n"
          Invoke-WebRequest -Uri $dlUrl -OutFile $tempZip -UseBasicParsing
          
          if (-not (Test-Path $tempZip)) { throw "Download failed." }
          
          # Extract IntuneWinAppUtil.exe from zip
          Add-Type -AssemblyName System.IO.Compression.FileSystem
          $zip = [System.IO.Compression.ZipFile]::OpenRead($tempZip)
          
          $entry = $zip.Entries | Where-Object { $_.Name -eq 'IntuneWinAppUtil.exe' } | Select-Object -First 1
          if (-not $entry) { 
             $zip.Dispose()
             Remove-Item $tempZip -Force
             throw "IntuneWinAppUtil.exe not found inside the downloaded zip." 
          }
          
          $result.StdOut += "Extracting $($entry.FullName)...`r`n"
          [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $TargetFile, $true)
          
          $zip.Dispose()
          Remove-Item $tempZip -Force
       }
       else {
          $result.StdOut += "Downloading from: $dlUrl`r`n"
          Invoke-WebRequest -Uri $dlUrl -OutFile $TargetFile -UseBasicParsing
       }
       
       if (Test-Path $TargetFile) {
          $result.StdOut += "Update complete."
       } else {
          throw "Download failed, file not found."
       }
    } catch {
       $result.ExitCode = -1
       $result.StdErr = $_.Exception.Message
    }
    
    [pscustomobject]$result
  }) | Out-Null
  
  $null = $ps.AddArgument($DestPath)
  $handle = $ps.BeginInvoke()

  $script:ActiveRunspace = $rs
  $script:AsyncPowerShell = $ps
  $script:AsyncResult = $handle
}

function Stop-AsyncIfAny {
  try {
    if ($script:AsyncPowerShell -and $script:AsyncResult -and -not $script:AsyncResult.IsCompleted) {
      try { $script:AsyncPowerShell.Stop() } catch {}
    }
  } catch {}
  try { if ($script:AsyncPowerShell) { $script:AsyncPowerShell.Dispose() } } catch {}
  try { if ($script:ActiveRunspace) { $script:ActiveRunspace.Close(); $script:ActiveRunspace.Dispose() } } catch {}
  $script:AsyncPowerShell = $null
  $script:AsyncResult = $null
  $script:ActiveRunspace = $null
}

#endregion

#region -------------------- Event Handlers --------------------
$SrcFolderBtn.Add_Click({
  if (-not (Guard-Action "Browse Source Folder")) { return }
  $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
  $dlg.Description = "Select package source folder"
  $dlg.RootFolder = "MyComputer"
  $dlg.SelectedPath = $ToolRoot
  if ($dlg.ShowDialog() -eq "OK") {
    $SrcFolderTxt.Text = $dlg.SelectedPath
    Write-Log ("Source folder set: {0}" -f $dlg.SelectedPath) "INFO"
    if ($OutSameRadio.IsChecked -eq $true) { $OutFolderTxt.Text = $dlg.SelectedPath }
    Auto-Detect-SourceFile -Folder $dlg.SelectedPath -Log $true
  }
  Refresh-UI
})

$SetupFileBtn.Add_Click({
  if (-not (Guard-Action "Browse Setup File")) { return }

  $src = Normalize-FullPath $SrcFolderTxt.Text
  if (-not $src -or -not (Test-Path $src)) {
    Write-Log "Select a valid Source folder first." "WARNING"
    return
  }

  $dlg = New-Object System.Windows.Forms.OpenFileDialog
  $dlg.InitialDirectory = $src
  $dlg.Filter = "Installer (*.exe;*.msi;*.ps1)|*.exe;*.msi;*.ps1|All files (*.*)|*.*"
  $dlg.Multiselect = $false
  if ($dlg.ShowDialog() -eq "OK") {
    $script:SetupFilePath = $dlg.FileName
    $SetupFileTxt.Text = [System.IO.Path]::GetFileName($dlg.FileName)
    Write-Log ("Setup file selected: {0}" -f ([System.IO.Path]::GetFileName($dlg.FileName))) "INFO"
  }
  Refresh-UI
})

$OutFolderBtn.Add_Click({
  if (-not (Guard-Action "Browse Output Folder")) { return }
  $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
  $dlg.Description = "Select output folder"
  $dlg.RootFolder = "MyComputer"
  $dlg.SelectedPath = $ToolRoot
  if ($dlg.ShowDialog() -eq "OK") {
    $OutFolderTxt.Text = $dlg.SelectedPath
    Write-Log ("Output folder set: {0}" -f $dlg.SelectedPath) "INFO"
  }
  Refresh-UI
})

$OutSameRadio.Add_Checked({ Refresh-UI })
$OutCustomRadio.Add_Checked({
  if (-not $script:IsBusy) {
    $src = Normalize-FullPath $SrcFolderTxt.Text
    $out = Normalize-FullPath $OutFolderTxt.Text
    if (-not $out -or ($src -and $out -eq $src)) { $OutFolderTxt.Text = $DefaultOutputPath }
  }
  Refresh-UI
})

$OpenOutBtn.Add_Click({
  $out = Normalize-FullPath $OutFolderTxt.Text
  if ($out -and (Test-Path $out)) {
    Start-Process explorer.exe -ArgumentList "`"$out`"" | Out-Null
  } else {
    Write-Log "Output folder not found." "WARNING"
  }
})

$ClearBtn.Add_Click({
  if (-not (Guard-Action "Clear")) { return }
  $SrcFolderTxt.Text = $DefaultSourcePath
  $script:SetupFilePath = $null
  $SetupFileTxt.Text = ""
  $OutFolderTxt.Text = $DefaultOutputPath
  $OutCustomRadio.IsChecked = $true
  $ProgressBar.Value = 0
  $script:LastProgress = 0
  Write-Log "Cleared inputs to defaults." "INFO"
  Refresh-UI
})

$NavCreateBtn.Add_Click({
  $ViewCreate.Visibility = 'Visible'
  $ViewExtract.Visibility = 'Collapsed'
  $NavCreateBtn.Background = "#D8E2F4"
  $NavCreateBtn.Foreground = "#1F2D3A"
  $NavExtractBtn.Background = "Transparent"
  $NavExtractBtn.Foreground = "#7C8BA1"
})

$NavExtractBtn.Add_Click({
  $ViewCreate.Visibility = 'Collapsed'
  $ViewExtract.Visibility = 'Visible'
  $NavCreateBtn.Background = "Transparent"
  $NavCreateBtn.Foreground = "#7C8BA1"
  $NavExtractBtn.Background = "#D8E2F4"
  $NavExtractBtn.Foreground = "#1F2D3A"
})

$ExtractFileBtn.Add_Click({
  if (-not (Guard-Action "Browse Extract File")) { return }
  $dlg = New-Object System.Windows.Forms.OpenFileDialog
  $dlg.Filter = "Intune Package (*.intunewin)|*.intunewin"
  if ($dlg.ShowDialog() -eq "OK") {
    $ExtractFileTxt.Text = $dlg.FileName
    Write-Log "Selected package to extract: $($dlg.FileName)" "INFO"
  }
})

$ExtractDestBtn.Add_Click({
  if (-not (Guard-Action "Browse Extract Dest")) { return }
  $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
  if ($dlg.ShowDialog() -eq "OK") {
    $ExtractDestTxt.Text = $dlg.SelectedPath
    Write-Log "Dest folder set: $($dlg.SelectedPath)" "INFO"
  }
})

$ExtractPullGraphBtn.Add_Click({
  if (-not (Guard-Action "Pull From Intune (Graph API)")) { return }

  $query = $ExtractIntuneQueryTxt.Text
  $dst = $ExtractDestTxt.Text

  if (-not $query) { Write-Log "Enter an Intune app name or app id to pull." "ERROR"; return }
  if (-not $dst) { Write-Log "Select a destination folder first." "ERROR"; return }
  if (-not (Test-Path $dst)) { New-Item -ItemType Directory -Path $dst -Force | Out-Null }

  Set-Busy $true
  $ProgressBar.Value = 10
  $script:LastProgress = 10
  Refresh-UI

  try {
    Write-Log ("Pulling Win32 app package from Intune (Graph API) for query: {0}" -f $query) "INFO"
    $pulledPkg = Get-IntuneWinFromIntune -AppQuery $query -DestinationFolder $dst

    if (-not $pulledPkg -or -not (Test-Path $pulledPkg)) {
      throw "Intune package pull did not produce a local .intunewin file."
    }

    $ExtractFileTxt.Text = $pulledPkg
    Write-Log ("Starting extraction for downloaded package: {0}" -f $pulledPkg) "INFO"

    $script:CurrentAction = 'Extract'
    $ProgressBar.Value = 20
    $script:LastProgress = 20
    Start-ExtractionAsync -ExtractInput ([pscustomobject]@{ IntuneWinFile = $pulledPkg; DestinationFolder = $dst })
  }
  catch {
    Write-Log ("Pull from Intune (Graph) failed: {0}" -f $_.Exception.Message) "ERROR"
    $ProgressBar.Value = 0
    $script:LastProgress = 0
    Set-Busy $false
    Refresh-UI
  }
})

$ExtractPullDeviceBtn.Add_Click({
  if (-not (Guard-Action "Pull From Intune (Device Cert)")) { return }

  $query = $ExtractIntuneQueryTxt.Text
  $dst = $ExtractDestTxt.Text

  if (-not $query) { Write-Log "Enter an Intune app name or app id to pull." "ERROR"; return }
  if (-not $dst) { Write-Log "Select a destination folder first." "ERROR"; return }
  if (-not (Test-Path $dst)) { New-Item -ItemType Directory -Path $dst -Force | Out-Null }

  Set-Busy $true
  $ProgressBar.Value = 10
  $script:LastProgress = 10
  Refresh-UI

  try {
    Write-Log ("Pulling Win32 app package from Intune (Device MDM Cert) for query: {0}" -f $query) "INFO"
    $appInfo = Get-IntuneWinViaDeviceCert -AppQuery $query -DestinationFolder $dst

    if (-not $appInfo) {
      throw "Device-cert pull did not return package information."
    }

    if ($appInfo.DecodedZip -and (Test-Path $appInfo.DecodedZip)) {
      $ExtractFileTxt.Text = $appInfo.DecodedZip
    }

    Write-Log ("Found app: {0} (ID: {1}, Version: {2})" -f $appInfo.DisplayName, $appInfo.Id, $appInfo.Version) "INFO"
    Write-Log ("Downloaded file: {0}" -f $appInfo.DownloadedFile) "INFO"
    Write-Log ("Decoded zip: {0}" -f $appInfo.DecodedZip) "INFO"

    $ProgressBar.Value = 100
    $script:LastProgress = 100
    Write-Log "Device-cert pull completed successfully." "INFO"
  }
  catch {
    Write-Log ("Pull from Intune (Device Cert) failed: {0}" -f $_.Exception.Message) "ERROR"
    $ProgressBar.Value = 0
    $script:LastProgress = 0
    Set-Busy $false
    Refresh-UI
    return
  }

  Set-Busy $false
  Refresh-UI
})

$ExtractRunBtn.Add_Click({
  if (-not (Guard-Action "Extract Package")) { return }
  
  $pkg = $ExtractFileTxt.Text
  $dst = $ExtractDestTxt.Text
  
  if (-not $pkg -or -not (Test-Path $pkg)) { Write-Log "Select a valid .intunewin file." "ERROR"; return }
  if (-not $dst) { Write-Log "Select a destination folder." "ERROR"; return }
  if (-not (Test-Path $dst)) { New-Item -ItemType Directory -Path $dst -Force | Out-Null }
  
  Set-Busy $true
  $script:CurrentAction = 'Extract'
  Refresh-UI
  
  $ProgressBar.Value = 10
  $script:LastProgress = 10
  Write-Log "Extraction started using internal decoder..." "INFO"
  
  Start-ExtractionAsync -ExtractInput ([pscustomobject]@{ IntuneWinFile=$pkg; DestinationFolder=$dst })
})

$ExtractOpenBtn.Add_Click({
  if ($ExtractDestTxt.Text -and (Test-Path $ExtractDestTxt.Text)) {
    Start-Process explorer.exe -ArgumentList "`"$($ExtractDestTxt.Text)`""
  }
})


$UpdateToolBtn.Add_Click({
  if (-not (Guard-Action "Update Tool")) { return }
  
  Set-Busy $true
  $script:CurrentAction = 'UpdateTool'
  $UpdateProgress.Visibility = 'Visible'
  $UpdateProgress.IsIndeterminate = $true
  Refresh-UI
  
  Write-Log "Starting tool update check..." "INFO"
  
  # If localIntuneWinUtil is invalid (e.g. read-only location), this might fail, but let's try
  $target = $localIntuneWinUtil
  Start-ToolUpdateAsync -DestPath $target
})

$CreateBtn.Add_Click({
  if (-not (Guard-Action "Create Package")) { return }

  $input = Validate-Inputs
  if (-not $input) { return }

  Set-Busy $true
  $script:CurrentAction = 'Create'
  Refresh-UI

  $ProgressBar.Value = 10
  $script:LastProgress = 10

  Write-Log "Packaging started..." "INFO"
  Write-Log ("Command: {0} {1}" -f $input.UtilPath, ("-c `"{0}`" -s `"{1}`" -o `"{2}`" -q" -f $input.SourceFolder, $input.SetupFile, $input.OutputFolder)) "INFO"

  try {
    Start-PackagingAsync -PkgInput $input
  } catch {
    Write-Log ("Failed to start packaging: {0}" -f $_.Exception.Message) "ERROR"
    Set-Busy $false
    Refresh-UI
    return
  }
})

#endregion

#region -------------------- Timers (Clock + Polling) --------------------
# clock
$clockTimer = New-Object System.Windows.Threading.DispatcherTimer
$clockTimer.Interval = [TimeSpan]::FromSeconds(1)
$clockTimer.Add_Tick({
  $ClockTxt.Text = (Get-Date).ToString("dd-MM-yyyy HH:mm:ss")
})
$clockTimer.Start()

# polling async job
$pollTimer = New-Object System.Windows.Threading.DispatcherTimer
$pollTimer.Interval = [TimeSpan]::FromMilliseconds(350)
$pollTimer.Add_Tick({

  # progress simulation while running
  if ($script:IsBusy -and $script:AsyncResult -and -not $script:AsyncResult.IsCompleted) {
    if ($script:LastProgress -lt 85) {
      $script:LastProgress += 1
      $ProgressBar.Value = $script:LastProgress
    }
    return
  }

  # completed?
  if ($script:IsBusy -and $script:AsyncResult -and $script:AsyncResult.IsCompleted) {
    try {
      $rawRes = $script:AsyncPowerShell.EndInvoke($script:AsyncResult)
      Stop-AsyncIfAny
      
      $res = $null
      if ($rawRes) {
          if ($rawRes.Count -gt 0) {
              $res = $rawRes[$rawRes.Count - 1] # Get the last object returned
          } elseif ($rawRes -isnot [System.Collections.ICollection]) {
              $res = $rawRes
          }
      }

      if ($res) {
        if ($res.StdOut) {
          ($res.StdOut -split "`r?`n") | Where-Object { $_.Trim() } | ForEach-Object { Write-Log $_ "INFO" }
        }
        if ($res.StdErr) {
          ($res.StdErr -split "`r?`n") | Where-Object { $_.Trim() } | ForEach-Object { Write-Log $_ "ERROR" }
        }

        $exitCode = $null
        # Robustly get ExitCode (PSCustomObject or Hashtable)
        if ($res.PSObject.Properties.Name -contains 'ExitCode') { 
            $exitCode = $res.ExitCode 
        } elseif ($res -is [System.Collections.IDictionary] -and $res.Contains('ExitCode')) {
            $exitCode = $res['ExitCode']
        }

        $successByText = ($res.StdOut -match 'has been generated successfully')
        $successByFile = ($res.OutputFiles -and $res.OutputFiles.Count -gt 0)
        
        # If updating, success is just ExitCode 0
        if ($script:CurrentAction -eq 'UpdateTool' -and $exitCode -eq 0) {
             # All good
        } elseif ($script:CurrentAction -eq 'Extract' -and $exitCode -eq 0) {
             # All good
        } elseif ($exitCode -eq $null -and -not ($successByText -or $successByFile)) {
          $exitCode = -1
          Write-Log "Worker process did not return a valid ExitCode. Object Type: $($res.GetType().Name)" "WARNING"
          if ($res.PSObject) {
             $props = $res.PSObject.Properties.Name -join ', '
             Write-Log "Available properties: $props" "WARNING"
          }
        }

        if ($exitCode -eq 0 -or $successByText -or $successByFile) {
          $ProgressBar.Value = 100
          $script:LastProgress = 100
          
          if ($script:CurrentAction -eq 'Extract') {
             Write-Log "Extraction process completed." "SUCCESS"
             if ($ExtractOpenBtn) { $ExtractOpenBtn.IsEnabled = $true }
          } elseif ($script:CurrentAction -eq 'UpdateTool') {
             Write-Log "IntuneWinAppUtil updated successfully." "SUCCESS"
             $UpdateProgress.Visibility = 'Collapsed'
             Check-ToolStatus
          } else {
            Write-Log "Packaging finished successfully." "SUCCESS"
            if ($res.OutputFiles -and $res.OutputFiles.Count -gt 0) {
              $of = $res.OutputFiles[0]
              $outMsg = $of
              try {
                $fi = Get-Item -LiteralPath $of -ErrorAction SilentlyContinue
                if ($fi) { $outMsg = ("{0} ({1})" -f $fi.Name, (Format-FileSize -Bytes $fi.Length)) }
                else { $outMsg = [System.IO.Path]::GetFileName($of) }
              } catch { $outMsg = [System.IO.Path]::GetFileName($of) }
              Write-Log ("Latest output: {0}" -f $outMsg) "SUCCESS"
              if ($OutPathInfoTxt -or $OutFileInfoTxt) {
                try {
                  $fi = Get-Item -LiteralPath $of -ErrorAction SilentlyContinue
                  if ($fi) {
                    if ($OutPathInfoTxt) {
                      $OutPathInfoTxt.Text = $fi.Name
                      $OutPathInfoTxt.Foreground = $BrushTextOk
                    }
                    if ($OutFileInfoTxt) {
                      $OutFileInfoTxt.Text = (Format-FileSize -Bytes $fi.Length)
                      $OutFileInfoTxt.Foreground = $BrushTextOk
                    }
                  }
                } catch {}
              }
            }
          }
        } else {
          $ProgressBar.Value = 0
          $script:LastProgress = 0
          Write-Log ("Process failed (ExitCode={0})." -f $exitCode) "ERROR"
          if ($script:CurrentAction -eq 'UpdateTool') {
             $UpdateProgress.Visibility = 'Collapsed'
          }
        }
      } else {
        Write-Log "No result returned from packaging worker." "ERROR"
      }
    }
    catch {
      Stop-AsyncIfAny
      Write-Log ("Async completion error: {0}" -f $_.Exception.Message) "ERROR"
    }
    finally {
      Set-Busy $false
      Refresh-UI
    }
  }
})
$pollTimer.Start()
#endregion

#region -------------------- Init --------------------
Write-Log ("Log file: {0}" -f $LogFile) "INFO"
Write-Log ("ToolRoot: {0}" -f $ToolRoot) "INFO"
Refresh-UI
Check-ToolStatus
#endregion

#region -------------------- Run --------------------
$w.Add_Closed({
  if ($script:clockTimer) { $script:clockTimer.Stop() }
  if ($script:pollTimer) { $script:pollTimer.Stop() }
  Stop-AsyncIfAny
  try { if ($script:LogWriter) { $script:LogWriter.Flush(); $script:LogWriter.Close(); $script:LogWriter.Dispose() } } catch {}
})
$null = $w.ShowDialog()
#endregion
