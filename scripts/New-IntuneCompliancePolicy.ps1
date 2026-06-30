<#
.SYNOPSIS
    Creates a Windows 10/11 device compliance policy in Microsoft Intune, then (optionally) assigns it
    to a group.
.DESCRIPTION
    Defines a sensible baseline of what a "healthy" managed Windows device looks like - BitLocker on,
    Secure Boot on, a real password, a minimum OS build, and Defender / antivirus required - and
    creates it as an Intune compliance policy via Microsoft Graph. A device that drifts out of these
    rules is marked non-compliant, which Conditional Access can then use to block access.

    Includes the required "scheduled action for rule" (mark non-compliant after a grace period), which
    Intune mandates when you create a compliance policy.
.PARAMETER DisplayName
    Name shown in the Intune admin center. Default: "Win10/11 - Baseline Compliance".
.PARAMETER MinimumOsVersion
    Minimum allowed OS build, e.g. 10.0.19045 (Win10 22H2) or 10.0.22631 (Win11 23H2).
.PARAMETER GroupId
    Optional Entra group object id to assign the policy to. Omit to create it unassigned.
.EXAMPLE
    .\New-IntuneCompliancePolicy.ps1
.EXAMPLE
    .\New-IntuneCompliancePolicy.ps1 -GroupId (Get-MgGroup -Filter "displayName eq 'Intune-Lab-Users'").Id
.NOTES
    Author: Tegan Wilton
    Scopes: DeviceManagementConfiguration.ReadWrite.All
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$DisplayName      = 'Win10/11 - Baseline Compliance',
    [string]$MinimumOsVersion = '10.0.19045',
    [string]$GroupId
)

. "$PSScriptRoot\Connect-IntuneGraph.ps1"
Connect-IntuneGraph -Scopes 'DeviceManagementConfiguration.ReadWrite.All'

# --- Policy definition -------------------------------------------------------
# A Windows compliance policy MUST ship with at least one scheduledActionForRule, otherwise the
# Graph create call fails. This one marks the device non-compliant 24h after it breaks a rule.
$body = @{
    '@odata.type'             = '#microsoft.graph.windows10CompliancePolicy'
    displayName               = $DisplayName
    description               = 'Baseline health: encryption, secure boot, password, min OS, antivirus.'
    passwordRequired          = $true
    passwordMinimumLength     = 8
    passwordRequiredType      = 'alphanumeric'
    osMinimumVersion          = $MinimumOsVersion
    bitLockerEnabled          = $true
    secureBootEnabled         = $true
    storageRequireEncryption  = $true
    defenderEnabled           = $true
    antivirusRequired         = $true
    antiSpywareRequired       = $true
    rtpEnabled                = $true
    scheduledActionsForRule   = @(
        @{
            ruleName = 'PasswordRequired'
            scheduledActionConfigurations = @(
                @{ actionType = 'block'; gracePeriodHours = 24; notificationTemplateId = '' }
            )
        }
    )
}

if ($PSCmdlet.ShouldProcess($DisplayName, 'Create Intune compliance policy')) {
    $policy = New-MgDeviceManagementDeviceCompliancePolicy -BodyParameter $body
    Write-Host "Created compliance policy: $($policy.DisplayName) ($($policy.Id))" -ForegroundColor Green

    # --- Optional assignment -------------------------------------------------
    if ($GroupId) {
        $assignment = @{
            assignments = @(
                @{ target = @{ '@odata.type' = '#microsoft.graph.groupAssignmentTarget'; groupId = $GroupId } }
            )
        }
        Invoke-MgGraphRequest -Method POST `
            -Uri "https://graph.microsoft.com/v1.0/deviceManagement/deviceCompliancePolicies/$($policy.Id)/assign" `
            -Body ($assignment | ConvertTo-Json -Depth 6)
        Write-Host "Assigned to group $GroupId" -ForegroundColor Green
    } else {
        Write-Host "Created unassigned - assign it in the Intune portal or pass -GroupId." -ForegroundColor DarkGray
    }
}
