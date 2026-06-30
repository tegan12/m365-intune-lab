# Setup Guide — M365 & Intune Endpoint Management Lab

Everything you need to take this repo from code → a working Intune tenant with an enrolled device and
the five screenshots the README expects. Budget ~1 evening (most of it is sign-ups and a VM install).

---

## 1. Get a tenant with Intune (free)

**Recommended: the Microsoft Intune free trial.** It's a 30-day EMS trial (Microsoft Entra ID P1/P2 +
Intune) that **auto-creates a brand-new tenant** for you — no existing account needed.

> ⚠️ Two things to know up front (both normal):
> - It asks for a **payment method**. The card is used for verification only and **isn't charged**
>   unless you buy something. Cancel before day 30 and you pay nothing.
> - **MFA is mandatory.** On your first admin sign-in you'll be prompted to set up multi-factor auth
>   (authenticator app or SMS) — do it; it's required for all Intune tenants now.

Steps:
1. Go to the **Intune Plan 1 trial** signup: https://go.microsoft.com/fwlink/?linkid=2019088
2. Enter an email → **Set up account** (create a new account).
3. Add name, phone, company name (anything, e.g. "Tegan IT Lab"), size, region (Ireland).
4. Verify your phone with the texted code.
5. Choose a **username + domain**: `admin` @ `teganitlab` → your tenant becomes
   `admin@teganitlab.onmicrosoft.com` (pick your own; this is what you'll sign in with).
6. Add the payment method (verification only). Finish — you'll get a confirmation email with your sign-in.

After sign-up you have a tenant like `yourname.onmicrosoft.com`. **Update `scripts/users.csv`** — swap the
`contoso.onmicrosoft.com` domain for *your* tenant domain before running `New-EntraUsersAndGroups.ps1`.

> The account that created the tenant is **Global Administrator** and already holds the trial licences,
> so it can enrol devices and run the scripts. (Other options if this one doesn't suit: a **Microsoft
> 365 Business Premium** 30-day trial also includes Intune; the old **Microsoft 365 Developer Program**
> free E5 sandbox is, as of 2025–2026, **restricted to Visual Studio Pro/Enterprise subscribers** — skip
> it unless you have one.)

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
host you used for the AD lab — a single Win11 VM at 2–3 GB RAM is fine on 8 GB).

**First, two one-time tenant settings (skip and enrolment silently fails):**
- **Turn on automatic enrolment:** Entra admin center (entra.microsoft.com) → **Devices → Mobility (MDM
  and MAM) → Microsoft Intune** → set **MDM user scope = All** → Save. (This is what makes an Entra-join
  auto-enrol into Intune.)
- **Make sure the account you'll sign in with has a licence:** Microsoft 365 admin center
  (admin.microsoft.com) → **Users → Active users →** your account → **Licenses and apps** → tick the
  Intune / EMS licence → Save. (The Global Admin that created the trial is usually already licensed.)

**Then enrol the VM:**
1. Build a **Windows 11** VM (or reuse `CLIENT01` from the AD lab — but first remove it from the domain:
   System → "Rename this PC (advanced)" → Member of **Workgroup** → reboot).
2. In the VM: **Settings → Accounts → Access work or school → Connect →** under "Alternate actions" pick
   **"Join this device to Microsoft Entra ID"**.
3. Sign in with your licensed tenant account (e.g. `admin@yourtenant.onmicrosoft.com`). Complete MFA if
   prompted. Accept → the device Entra-joins and auto-enrols into Intune.
4. Reboot and sign in to Windows with that work account. Wait ~5–10 min for the first sync.
5. In the **Intune admin center** (intune.microsoft.com) → **Devices → All devices** the VM appears.
   Run `Get-IntuneDeviceReport.ps1` and it shows up there too.

> No VM spare? Enrolling your own physical Windows PC also works — but a throwaway VM is cleaner and
> reversible (you're handing device management to a 30-day trial tenant).

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
