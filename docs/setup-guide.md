# Setup Guide — M365 & Intune Endpoint Management Lab

Everything you need to take this repo from code → a working Intune tenant with an enrolled device and
the five screenshots the README expects. Budget ~1 evening (most of it is sign-ups and a VM install).

---

## 1. Get a tenant with Intune (free)

Pick **one**:

| Option | Cost | Intune included? | Notes |
|--------|------|------------------|-------|
| **Microsoft 365 Developer Program** | Free | Yes (E5 sandbox) | Best option. Go to developer.microsoft.com → "Join" → set up the instant sandbox. Gives you 25 E5 licences incl. Intune. Eligibility can require a qualifying account — try this first. |
| **Microsoft 365 Business Premium trial** | Free 30 days | Yes | Sign up at microsoft.com/microsoft-365/business → "Try free". Needs a card; cancel before day 30. |
| **EMS E5 trial** | Free 90 days | Yes | Add on top of any free tenant — search "Enterprise Mobility + Security E5 trial". |

After sign-up you get a tenant like `yourname.onmicrosoft.com`. **Update `scripts/users.csv`** — swap the
`contoso.onmicrosoft.com` domain for your real tenant domain before running `New-EntraUsersAndGroups.ps1`.

> Assign yourself an Intune/EMS licence (Microsoft 365 admin center → Users → your account → Licences),
> or device enrolment will fail.

---

## 2. Install the tools (on your PC)

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser   # the Graph PowerShell SDK
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```
First `Connect-MgGraph` opens a browser to sign in and consent to the scopes — sign in as your tenant
admin. (If your tenant is brand-new, you may be asked to set up MFA — do it.)

---

## 3. Enrol a Windows device

You need at least one device in Intune for the device screenshots. Easiest is a VM (the same VirtualBox
host you used for the AD lab — a single Win11 VM at 2–3 GB RAM is fine on 8 GB):

1. Build a **Windows 11** VM (or reuse `CLIENT01` from the AD lab — but reset it so it's workgroup, not
   domain-joined).
2. In the VM: **Settings → Accounts → Access work or school → Connect → "Join this device to Microsoft
   Entra ID"**.
3. Sign in with one of the cloud users you created (or your admin) — the device auto-enrols into Intune.
4. Wait a few minutes, then in the **Intune admin center** (intune.microsoft.com) → **Devices** the VM
   appears. Run `Get-IntuneDeviceReport.ps1` and it shows up there too.

> No VM spare? Even enrolling your own physical Windows PC works — but a throwaway VM is cleaner and
> reversible.

---

## 4. Run the scripts (creates the things you'll screenshot)

```powershell
# from the repo root
.\scripts\New-EntraUsersAndGroups.ps1 -CsvPath .\scripts\users.csv
$g = (Get-MgGroup -Filter "displayName eq 'Intune-Lab-Users'").Id
.\scripts\New-IntuneCompliancePolicy.ps1 -GroupId $g
.\scripts\New-IntuneConfigProfile.ps1   -GroupId $g
.\scripts\Get-IntuneDeviceReport.ps1    -CsvPath .\devices.csv
```
Tip: add `-WhatIf` to any `New-*` script first to preview without creating.

---

## 5. Capture the 5 screenshots

Save each as PNG into `docs/screenshots/` with the **exact filename** so the README picks it up:

| Filename | Where | What to show |
|----------|-------|--------------|
| `enrolled-device.png` | Intune admin center → Devices → your VM | The device overview (name, OS, ownership, compliance). |
| `compliance-policy.png` | Devices → Compliance policies → "Win10/11 - Baseline Compliance" | The policy settings page. |
| `config-profile.png` | Devices → Configuration → "Win10/11 - Device Restrictions" | The profile + its group assignment. |
| `entra-users.png` | Entra admin center → Users (or Groups → Intune-Lab-Users → Members) | The 5 cloud users / the group membership. |
| `device-report.png` | Your PowerShell window | The `Get-IntuneDeviceReport.ps1` console output (table + compliant/non-compliant summary). |

> For the PowerShell console shot, make the window a sensible size and use a light/dark theme that reads
> well. Crop tightly.

---

## 6. Hand them to me
Drop the PNGs into `docs/screenshots/` and tell me — I'll verify them, confirm the README embeds resolve,
commit and push to `github.com/tegan12/m365-intune-lab`, then it's ready to pin + add to LinkedIn Featured.

---

## Cleanup (free up the tenant / RAM)
- Delete the test compliance policy / config profile / users in the portal when done (or keep them — a
  populated tenant looks better in screenshots).
- Power off / delete the VM to free RAM.
- Cancel any paid trial before it bills.
