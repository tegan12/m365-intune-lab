<#
.SYNOPSIS
    Bulk-creates Microsoft Entra ID (Azure AD) cloud users from a CSV and drops them into a security
    group - the cloud equivalent of the on-prem bulk-user script in my AD Home Lab.
.DESCRIPTION
    Reads a CSV of users, creates each one in Entra ID with a forced password change at first sign-in,
    sets a usage location (required before licences can be assigned), then creates a target security
    group (if it doesn't already exist) and adds every user to it. That group is what you target your
    Intune compliance/configuration policies at.

    Re-runnable: users that already exist are skipped, not duplicated.
.PARAMETER CsvPath
    Path to the users CSV. Columns: DisplayName, UserPrincipalName, MailNickname, Department, JobTitle.
.PARAMETER GroupName
    Display name of the security group to create / reuse. Default: "Intune-Lab-Users".
.PARAMETER InitialPassword
    The temporary password set on every new account (users must change it at first sign-in).
.PARAMETER UsageLocation
    Two-letter country code for licence eligibility. Default: IE (Ireland).
.EXAMPLE
    .\New-EntraUsersAndGroups.ps1 -CsvPath .\users.csv
.NOTES
    Author: Tegan Wilton
    Scopes: User.ReadWrite.All, Group.ReadWrite.All
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$CsvPath        = "$PSScriptRoot\users.csv",
    [string]$GroupName      = 'Intune-Lab-Users',
    [string]$InitialPassword = 'Lab-Passw0rd-Change!',
    [string]$UsageLocation  = 'IE'
)

. "$PSScriptRoot\Connect-IntuneGraph.ps1"
Connect-IntuneGraph -Scopes 'User.ReadWrite.All', 'Group.ReadWrite.All'

if (-not (Test-Path $CsvPath)) { throw "CSV not found: $CsvPath" }
$rows = Import-Csv $CsvPath

# --- Create / reuse the security group --------------------------------------
$mailNick = ($GroupName -replace '[^A-Za-z0-9]', '').ToLower()
$group = Get-MgGroup -Filter "displayName eq '$GroupName'" -ConsistencyLevel eventual -CountVariable c -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $group) {
    if ($PSCmdlet.ShouldProcess($GroupName, 'Create security group')) {
        $group = New-MgGroup -DisplayName $GroupName -MailEnabled:$false -MailNickname $mailNick `
                             -SecurityEnabled -GroupTypes @()
        Write-Host "Created group: $GroupName ($($group.Id))" -ForegroundColor Green
    }
} else {
    Write-Host "Group already exists: $GroupName ($($group.Id))" -ForegroundColor DarkGray
}

# --- Create users + add to group --------------------------------------------
$created = 0; $skipped = 0
foreach ($r in $rows) {
    $existing = Get-MgUser -Filter "userPrincipalName eq '$($r.UserPrincipalName)'" -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "  skip (exists): $($r.UserPrincipalName)" -ForegroundColor DarkGray
        $user = $existing
        $skipped++
    }
    elseif ($PSCmdlet.ShouldProcess($r.UserPrincipalName, 'Create Entra user')) {
        $pwProfile = @{ Password = $InitialPassword; ForceChangePasswordNextSignIn = $true }
        $user = New-MgUser -DisplayName $r.DisplayName `
                           -UserPrincipalName $r.UserPrincipalName `
                           -MailNickname $r.MailNickname `
                           -Department $r.Department `
                           -JobTitle $r.JobTitle `
                           -UsageLocation $UsageLocation `
                           -AccountEnabled `
                           -PasswordProfile $pwProfile
        Write-Host "  created: $($r.UserPrincipalName)" -ForegroundColor Green
        $created++
    }

    if ($group -and $user) {
        try {
            New-MgGroupMember -GroupId $group.Id -DirectoryObjectId $user.Id -ErrorAction Stop
        } catch {
            # Already a member -> Graph returns 400; ignore that specific case.
            if ($_.Exception.Message -notmatch 'already exist') { Write-Warning $_.Exception.Message }
        }
    }
}

Write-Host "`nDone. Created $created, skipped $skipped. Group '$GroupName' is ready to target with Intune policies." -ForegroundColor Cyan
