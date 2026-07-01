<#
.SYNOPSIS
    Reports every device enrolled in Microsoft Intune - owner, OS, compliance state and last check-in -
    to the console and, optionally, a CSV or HTML report.
.DESCRIPTION
    A read-only inventory of the managed fleet. This is the kind of report a help-desk / sysadmin runs
    to spot devices that are non-compliant or haven't checked in for a while, before they become a
    support call. Uses Microsoft Graph; changes nothing.
.PARAMETER StaleDays
    Flag devices that haven't synced in this many days. Default: 7.
.PARAMETER CsvPath
    Optional path to export the full table as CSV.
.PARAMETER HtmlPath
    Optional path to save a styled HTML report.
.EXAMPLE
    .\Get-IntuneDeviceReport.ps1
.EXAMPLE
    .\Get-IntuneDeviceReport.ps1 -CsvPath .\devices.csv -StaleDays 14
.NOTES
    Author: Tegan Wilton
    Scopes: DeviceManagementManagedDevices.Read.All
#>
[CmdletBinding()]
param(
    [int]$StaleDays = 7,
    [string]$CsvPath,
    [string]$HtmlPath
)

. "$PSScriptRoot\Connect-IntuneGraph.ps1"
Connect-IntuneGraph -Scopes 'DeviceManagementManagedDevices.Read.All'

$devices = Get-MgDeviceManagementManagedDevice -All
if (-not $devices) {
    Write-Warning "No managed devices found. Enrol a device in Intune first (see docs/setup-guide.md)."
    return
}

$staleCutoff = (Get-Date).AddDays(-$StaleDays)

$report = @(foreach ($d in $devices) {
    [PSCustomObject]@{
        DeviceName     = $d.DeviceName
        User           = $d.UserPrincipalName
        OS             = "$($d.OperatingSystem) $($d.OsVersion)"
        Ownership      = $d.ManagedDeviceOwnerType
        Compliance     = $d.ComplianceState
        LastSync       = $d.LastSyncDateTime
        StaleCheckIn   = ($d.LastSyncDateTime -lt $staleCutoff)
        Model          = "$($d.Manufacturer) $($d.Model)".Trim()
    }
})

# --- Console report ----------------------------------------------------------
Write-Host "`n=== Intune Managed Devices ($($report.Count)) ===" -ForegroundColor Cyan
$report | Sort-Object Compliance, DeviceName | Format-Table -AutoSize

$nonCompliant = @($report | Where-Object { $_.Compliance -ne 'compliant' })
$stale        = @($report | Where-Object { $_.StaleCheckIn })
Write-Host ("Compliant: {0}  |  Non-compliant/unknown: {1}  |  Stale (>{2}d): {3}" -f `
    ($report.Count - $nonCompliant.Count), $nonCompliant.Count, $StaleDays, $stale.Count) -ForegroundColor Cyan
if ($nonCompliant) { Write-Warning "$($nonCompliant.Count) device(s) not compliant - review before they cause access issues." }

# --- Optional exports --------------------------------------------------------
if ($CsvPath) {
    $report | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding utf8
    Write-Host "CSV saved to $CsvPath" -ForegroundColor Green
}
if ($HtmlPath) {
    $style = "<style>body{font-family:Segoe UI,Arial} table{border-collapse:collapse} " +
             "th,td{border:1px solid #ccc;padding:6px 10px} th{background:#0a2540;color:#fff}</style>"
    $report | ConvertTo-Html -Title 'Intune Device Report' -PreContent "$style<h1>Intune Device Report</h1>" |
        Out-File -FilePath $HtmlPath -Encoding utf8
    Write-Host "HTML report saved to $HtmlPath" -ForegroundColor Green
}
