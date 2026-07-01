<#
.SYNOPSIS
    Creates a Windows 10/11 device configuration profile (device restrictions) in Microsoft Intune.
.DESCRIPTION
    Where a compliance policy *checks* a device, a configuration profile *configures* it. This one
    pushes a small, sensible set of password and encryption settings to enrolled Windows devices -
    the kind of hardening baseline you'd roll out on day one of managing a fleet - via Microsoft Graph.
.PARAMETER DisplayName
    Name shown in the Intune admin center. Default: "Win10/11 - Device Restrictions".
.PARAMETER GroupId
    Optional Entra group object id to assign the profile to. Omit to create it unassigned.
.EXAMPLE
    .\New-IntuneConfigProfile.ps1
.NOTES
    Author: Tegan Wilton
    Scopes: DeviceManagementConfiguration.ReadWrite.All
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$DisplayName = 'Win10/11 - Device Restrictions',
    [string]$GroupId
)

. "$PSScriptRoot\Connect-IntuneGraph.ps1"
Connect-IntuneGraph -Scopes 'DeviceManagementConfiguration.ReadWrite.All'

# Idempotency: if a profile with this name already exists, don't create a duplicate.
$existing = Get-MgDeviceManagementDeviceConfiguration -All -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -eq $DisplayName } | Select-Object -First 1
if ($existing) {
    Write-Warning "Configuration profile '$DisplayName' already exists ($($existing.Id)) - skipping (idempotent). Pass a different -DisplayName to create another."
    return
}

# --- Profile definition ------------------------------------------------------
$body = @{
    '@odata.type'                    = '#microsoft.graph.windows10GeneralConfiguration'
    displayName                      = $DisplayName
    description                      = 'Baseline hardening: device password rules + storage encryption.'
    passwordRequired                 = $true
    passwordBlockSimple              = $true
    passwordMinimumLength            = 8
    passwordRequiredType             = 'alphanumeric'
    passwordMinimumCharacterSetCount = 3
    passwordExpirationDays           = 90
    passwordPreviousPasswordBlockCount = 5
    storageRequireDeviceEncryption   = $true
}

if ($PSCmdlet.ShouldProcess($DisplayName, 'Create Intune configuration profile')) {
    $cfg = New-MgDeviceManagementDeviceConfiguration -BodyParameter $body
    Write-Host "Created configuration profile: $($cfg.DisplayName) ($($cfg.Id))" -ForegroundColor Green

    if ($GroupId) {
        $assignment = @{
            assignments = @(
                @{ target = @{ '@odata.type' = '#microsoft.graph.groupAssignmentTarget'; groupId = $GroupId } }
            )
        }
        Invoke-MgGraphRequest -Method POST `
            -Uri "https://graph.microsoft.com/v1.0/deviceManagement/deviceConfigurations/$($cfg.Id)/assign" `
            -Body ($assignment | ConvertTo-Json -Depth 6)
        Write-Host "Assigned to group $GroupId" -ForegroundColor Green
    } else {
        Write-Host "Created unassigned - assign it in the Intune portal or pass -GroupId." -ForegroundColor DarkGray
    }
}
