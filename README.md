# Fix-AzureCLI — ConnectionResetError 10054 One-Click Repair

> **One-click PowerShell script** that fixes the dreaded `ConnectionResetError(10054)` when using Azure CLI on Windows personal laptops.

---

## The Error This Fixes

```
('Connection aborted.', ConnectionResetError(10054, 'An existing connection was
forcibly closed by the remote host', None, 10054, None))
```

---

## Quick Start

```powershell
# Open PowerShell (no need to run as Admin — script self-elevates)
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force; .\Fix-AzureCLI.ps1
```

Then **restart your PC** and run `az login`.

---

## What the Script Fixes (8 Steps)

| Step | Fix |
|------|-----|
| 1 | Flush DNS + reset Winsock & TCP/IP stack |
| 2 | Disable IPv6 on all active network adapters |
| 3 | Set `AZURE_CLI_DISABLE_CONNECTION_VERIFY` system-wide |
| 4 | Clear `~\.azure` folder (corrupt tokens & certs) |
| 5 | Force TLS 1.2 via Windows registry, disable TLS 1.0/1.1 |
| 6 | Add Windows Firewall outbound rules for az + python |
| 7 | Auto-upgrade Azure CLI to latest version |
| 8 | Test live connectivity to Azure endpoints |

---

## Requirements

- Windows 10 or Windows 11
- Azure CLI installed ([download here](https://aka.ms/installazurecliwindows))
- PowerShell 5.1 or later (built into Windows)

---

## Usage

### Option A — Right-click (Easiest)
1. Download `Fix-AzureCLI.ps1`
2. Right-click the file → **Run with PowerShell**
3. Click **Yes** on the UAC Admin prompt
4. Restart when prompted
5. Run `az login`

### Option B — From PowerShell terminal
```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
.\Fix-AzureCLI.ps1
```

---

## Still Failing After Restart?

Run this command:
```powershell
az login --debug 2>&1 | Tee-Object debug.txt
```
## License

MIT
