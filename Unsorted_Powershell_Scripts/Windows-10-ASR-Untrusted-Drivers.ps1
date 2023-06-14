<# 
.SYNOPSIS
   To enable ASR Block abuse of exploited vulnerable signed drivers

.DESCRIPTION
   Add new ASR Rule that is not implemented via MEM ASR
   See here: https://docs.microsoft.com/en-us/microsoft-365/security/defender-endpoint/enable-attack-surface-reduction?view=o365-worldwide#powershell

.EXAMPLE
   PS C:\> .\Windows-10-ASR-Untrusted-Drivers.ps1
   Save the file to your hard drive with a .PS1 extention and run the file from an elavated PowerShell prompt.

.FUNCTIONALITY
   PowerShell v4+
#>

Add-MpPreference -AttackSurfaceReductionRules_Ids 56a863a9-875e-4185-98a7-b882c64b5ce5 -AttackSurfaceReductionRules_Actions Enabled