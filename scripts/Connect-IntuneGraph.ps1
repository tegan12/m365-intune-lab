<#
.SYNOPSIS
    Shared helper that connects to Microsoft Graph with a given set of scopes.
.DESCRIPTION
    Dot-source this file from the other scripts in this repo so the connection logic lives in one
    place. It reuses an existing Microsoft Graph session when the needed scopes are already granted,
    and only prompts for sign-in when something is missing - so re-running scripts back-to-back
    doesn't pop a login window every time.
.PARAMETER Scopes
    The delegated Microsoft Graph permission scopes the calling script needs.
.EXAMPLE
    . "$PSScriptRoot\Connect-IntuneGraph.ps1"
    Connect-IntuneGraph -Scopes 'DeviceManagementManagedDevices.Read.All'
.NOTES
    Author: Tegan Wilton
    Requires the Microsoft Graph PowerShell SDK:  Install-Module Microsoft.Graph -Scope CurrentUser
#>
function Connect-IntuneGraph {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Scopes
    )

    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
        throw "Microsoft Graph SDK not found. Install it first:  Install-Module Microsoft.Graph -Scope CurrentUser"
    }

    # Reuse the current session if it already has every scope we need.
    $ctx = Get-MgContext
    if ($ctx) {
        $missing = $Scopes | Where-Object { $_ -notin $ctx.Scopes }
        if (-not $missing) {
            Write-Verbose "Reusing existing Microsoft Graph session for $($ctx.Account)."
            return
        }
        # Connected, but missing a scope - reconnect asking for the full set.
        $Scopes = @($ctx.Scopes + $Scopes | Select-Object -Unique)
    }

    Write-Host "Connecting to Microsoft Graph (scopes: $($Scopes -join ', '))..." -ForegroundColor Cyan
    Connect-MgGraph -Scopes $Scopes -NoWelcome
    $who = (Get-MgContext).Account
    Write-Host "Connected as $who" -ForegroundColor Green
}
