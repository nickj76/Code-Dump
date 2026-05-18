<#
.SYNOPSIS
Diagnostic tool to check Intune MDM device certificate and enrollment status.
Run this if "Pull via Device Cert" fails with certificate not found.
#>

Write-Host "=== Intune Device Certificate Diagnostic ===" -ForegroundColor Cyan

# Check 1: Enrollment Status
Write-Host "`n[1] Checking Device Enrollment Status..." -ForegroundColor Yellow
$regPath = "HKLM:\SOFTWARE\Microsoft\Enrollments"
$enrollments = @(Get-ChildItem $regPath -ErrorAction SilentlyContinue)

if ($enrollments.Count -eq 0) {
  Write-Host "  ❌ NO ENROLLMENTS FOUND - Device may not be Intune-enrolled" -ForegroundColor Red
} else {
  Write-Host "  ✓ Found $($enrollments.Count) enrollment(s)" -ForegroundColor Green
  foreach ($enrollment in $enrollments) {
    $props = Get-ItemProperty $enrollment.PSPath -ErrorAction SilentlyContinue
    Write-Host "    - State: $($props.EnrollmentState), UPN: $($props.UPN), DeviceId: $($props.DeviceId)" -ForegroundColor Gray
  }
}

# Check 2: Certificate Stores
Write-Host "`n[2] Scanning Certificate Stores..." -ForegroundColor Yellow
$stores = @("LocalMachine\My", "LocalMachine\Root", "LocalMachine\TrustedPeople", "LocalMachine\CA", "CurrentUser\My")
$totalCerts = 0

foreach ($store in $stores) {
  try {
    $certs = @(Get-ChildItem "Cert:\$store" -ErrorAction SilentlyContinue)
    if ($certs.Count -gt 0) {
      Write-Host "  Cert:\$store - Found $($certs.Count) certificate(s)" -ForegroundColor Green
      foreach ($cert in $certs | Select-Object -First 5) {
        Write-Host "    ├─ Subject: $($cert.Subject)" -ForegroundColor Gray
        Write-Host "    ├─ Issuer: $($cert.Issuer)" -ForegroundColor Gray
        Write-Host "    ├─ Thumbprint: $($cert.Thumbprint)" -ForegroundColor Gray
        Write-Host "    └─ Valid: $($cert.NotBefore) to $($cert.NotAfter)" -ForegroundColor Gray
      }
      $totalCerts += $certs.Count
    } else {
      Write-Host "  Cert:\$store - No certificates" -ForegroundColor Gray
    }
  } catch {
    Write-Host "  Cert:\$store - Error: $_" -ForegroundColor Red
  }
}

if ($totalCerts -eq 0) {
  Write-Host "`n  ⚠️  WARNING: No certificates found in any store!" -ForegroundColor Yellow
  Write-Host "     This is likely why device-based pull is failing." -ForegroundColor Yellow
}

# Check 3: Intune Management Extension
Write-Host "`n[3] Checking Intune Management Extension..." -ForegroundColor Yellow
$ime = Get-Service "IntuneManagementExtension" -ErrorAction SilentlyContinue
if ($ime) {
  Write-Host "  ✓ Service exists - Status: $($ime.Status)" -ForegroundColor Green
  if ($ime.Status -ne "Running") {
    Write-Host "    ⚠️  Service is not running! Bearer token retrieval may fail." -ForegroundColor Yellow
  }
} else {
  Write-Host "  ❌ Service not found - Device may not be enrolled" -ForegroundColor Red
}

# Check 4: Token Broker Cache
Write-Host "`n[4] Checking Token Broker Cache..." -ForegroundColor Yellow
$cachePath = "$env:LOCALAPPDATA\Microsoft\TokenBroker\Cache"
if (Test-Path $cachePath) {
  $tbresFiles = @(Get-ChildItem $cachePath -Filter *.tbres -ErrorAction SilentlyContinue)
  Write-Host "  ✓ Token cache found - $($tbresFiles.Count) token file(s)" -ForegroundColor Green
  if ($tbresFiles.Count -eq 0) {
    Write-Host "    ⚠️  No tokens cached yet. Run 'gpupdate /force' and re-enroll." -ForegroundColor Yellow
  }
} else {
  Write-Host "  ❌ Token cache path not found" -ForegroundColor Red
}

# Summary
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
$issues = @()
if ($enrollments.Count -eq 0) { $issues += "Device not enrolled" }
if ($totalCerts -eq 0) { $issues += "No certificates installed" }
if ($ime -and $ime.Status -ne "Running") { $issues += "IME service not running" }

if ($issues.Count -eq 0) {
  Write-Host "✓ Device appears ready for MTLS-based Intune pull" -ForegroundColor Green
} else {
  Write-Host "❌ Issues found that need to be resolved:" -ForegroundColor Red
  foreach ($issue in $issues) {
    Write-Host "  • $issue" -ForegroundColor Yellow
  }
  Write-Host "`n📋 Recommended next steps:" -ForegroundColor Cyan
  Write-Host "  1. Run 'gpupdate /force' to sync Group Policy" -ForegroundColor Gray
  Write-Host "  2. Verify device is in Intune portal (Devices > All devices)" -ForegroundColor Gray
  Write-Host "  3. Check if enrollment certificate appears in 'Cert:\LocalMachine\My'" -ForegroundColor Gray
  Write-Host "  4. Restart IntuneManagementExtension service" -ForegroundColor Gray
  Write-Host "  5. Try Graph API pull as alternative (usually more reliable)" -ForegroundColor Gray
}

Write-Host "`n"
