# pcairplay

Mirror an iPhone screen to a Windows PC using **native iOS Screen Mirroring** —
no app on the phone.

The phone sees the PC in Control Center → Screen Mirroring, exactly like an
Apple TV. Nothing to install on iOS, nothing to sideload.

> ✅ **Verified end to end** (2026-07-20): an iPhone on the home Wi-Fi found the
> PC in Screen Mirroring and completed a full mirroring session, no cable. See
> [Status](#status).

## How it works

This repo is **Windows glue, not protocol code**. The receiver itself is
[UxPlay](https://github.com/FDH2/UxPlay) (via the prebuilt
[uxplay-windows](https://github.com/leapbtw/uxplay-windows) build), which
implements the hard parts: mDNS advertisement, RTSP, the FairPlay handshake,
pair-verify, and H.264 over RTP.

What's added here is the part that's otherwise fiddly and badly documented:
install, firewall rules, mDNS prerequisites, low-latency defaults, and a
diagnostic script that names the actual cause when it doesn't work.

## Requirements

- Windows 10/11, Windows PowerShell 5.1 (the built-in one — PowerShell 7 not needed).
- **Apple Bonjour.** UxPlay 1.72 imports `dnssd.dll` and calls `DNSServiceRegister`
  to advertise itself, so without Bonjour the receiver runs but never appears on
  the phone. iTunes installs it; otherwise get
  [Bonjour Print Services for Windows](https://support.apple.com/kb/DL999).
  `setup.ps1` checks for it and stops if it's missing.

## Install

### Option A — installer (recommended)

Download **`pcairplay-setup-<version>.exe`** from the
[latest release](https://github.com/gbulog/pcairplay/releases/latest) and run
it. It installs the scripts plus Start Menu shortcuts (**AirPlay UI**,
**AirPlay Diagnostics**), then offers to run first-time setup — which
downloads the UxPlay engine (pinned 1.72.1-3, SHA-256-checked against the
upstream release) and opens the firewall. If Apple Bonjour is missing, setup
says so and points at Apple's own installer — see *Requirements* above.

Your browser may flag the download itself (Edge: "…isn't commonly
downloaded") — that is reputation for a new unsigned exe, not a detection.
In Edge: hover the download → **⋯ → Keep → Show more → Keep anyway**. Windows
SmartScreen may then warn once more when you run it ("Windows protected your
PC") — click **More info → Run anyway**, or verify the download against
`SHA256SUMS.txt` on the release page first. The exe contains
only the scripts in this repo; the engine comes from
[uxplay-windows](https://github.com/leapbtw/uxplay-windows)'s own release at
install time.

To remove it later: **Settings → Apps → pcairplay**. The uninstaller also
removes the firewall rules; UxPlay and Bonjour keep their own Apps & Features
entries.

### Option B — ZIP / clone

```powershell
# If you downloaded a ZIP rather than cloning, unblock the files first:
Get-ChildItem *.ps1, *.cmd | Unblock-File

# 1. Elevated PowerShell, in this directory:
powershell -ExecutionPolicy Bypass -File .\setup.ps1

# 2. Verify (double-click "Diagnostics.cmd", or):
powershell -ExecutionPolicy Bypass -File .\doctor.ps1

# 3. Start the receiver — either one:
powershell -ExecutionPolicy Bypass -File .\start-airplay.ps1
#   ...or just double-click "AirPlay UI.vbs" for the desktop UI
#   ("AirPlay UI.cmd" does the same; the .vbs opens with zero window flashes)
```

Undo it all later with `setup.ps1 -Uninstall` (removes the firewall rules and
nothing else).

Then on the iPhone: **Control Center → Screen Mirroring → pick the PC**.

> **Which UxPlay build?** `setup.ps1` deliberately installs **1.72.1-3**, not the
> latest release. UxPlay 2.x is a Qt6 rewrite that links uxplay in as a library
> and ships **no `uxplay.exe` and no command line** — verified by reading the
> published 2.0.0.1736 archive. These scripts drive the engine by command line,
> so 2.x cannot be used here and `setup.ps1` refuses it. See
> [CLAUDE.md](CLAUDE.md#the-1x--2x-split--read-this-before-touching-setupps1).

## The UI

`airplay-ui.ps1` is a self-contained WPF app over the same engine — device name,
latency mode, resolution and framerate, fullscreen, the iPhone-style frame,
share-safe video and PIN, one Start/Stop button, and a shortcut to the
diagnostics. Double-click **`AirPlay UI.vbs`** to launch it — nothing else
appears: no console windows, no taskbar blips, not even while the engine runs
(it lives in a hidden console the UI manages).

The **iPhone frame** switch wraps the live mirror in a phone-shaped chassis —
bezel, rounded corners, side buttons (`frame-mirror.ps1` doing the work). The
frame opens with the UI, remembers its position and size, and the switch works
mid-session in both directions. **Closing the UI closes everything**: receiver,
engine, frame — one predictable rule, nothing left behind.

**Fullscreen** and the frame are mutually exclusive — fullscreen fills the
monitor with the video itself, so there is nothing for a chassis to wrap;
switching either one on switches the other off.

Settings persist across launches (`%LOCALAPPDATA%\pcairplay\ui-settings.json`).
With **Require PIN** on, the 4-digit code appears right in the window under the
status and stays there for the whole session, including while mirroring — the
UI generates it and hands it to the engine, so there is no console to go read.
The UI is single-instance: launching it twice just surfaces the window that is
already open.

The status it shows is **"Discoverable" / "iPhone connected" / "Mirroring"**,
derived from the engine's actual sockets and log — it names the documented
"connected but no video" stall too, with the phone-side reset that clears it.

While the receiver is live the settings visibly recede and lock (the frame
switch stays live on purpose). `airplay-ui.ps1 -SelfTest` builds the whole
window, asserts its layout geometry and the exact engine command line, and
exits — run it after any edit there.

It also detects **competing AirPlay receivers** (PigeonCast, AirServer,
Reflector, a stale `uxplay`) and offers to close them. This matters: a second
receiver holds port 7000 *and* advertises a second entry in the iPhone's
mirroring list, so it's easy to pick the wrong one.

## Usage

```powershell
.\start-airplay.ps1                              # low-latency defaults
.\start-airplay.ps1 -Name "Demo Screen"          # rename as shown on the phone
.\start-airplay.ps1 -Fullscreen
.\start-airplay.ps1 -Sync                        # correct lip-sync, for video
.\start-airplay.ps1 -Fps 30                      # if the network stutters
.\start-airplay.ps1 -Pin                         # require a PIN to connect
.\start-airplay.ps1 -NoLog                       # don't write a log this run
```

Both launchers write logs to `%LOCALAPPDATA%\pcairplay\`, keeping the last five
runs. This is on by default — if mirroring misbehaves, that directory is the
first thing to look at, and the first thing to send.

Defaults are tuned for **demos and app screen-sharing** — responsiveness over
perfect A/V sync. Use `-Sync` when watching video, where lip-sync matters more
than latency.

## When it doesn't work

Run `.\doctor.ps1 -PhoneIP <iphone-ip>` first. It checks, in the order these
actually bite:

1. **Windows Firewall / Public network profile** — blocks inbound mDNS, so the
   PC never appears in the list. Fix: `setup.ps1 -SetNetworkPrivate`.
2. **AP / client isolation on the router** — blocks Wi-Fi clients from reaching
   wired devices. Common on guest SSIDs, and the classic killer of the
   wired-PC / Wi-Fi-phone setup.
3. **Phone on a different subnet or guest SSID** — mDNS doesn't route across
   subnets.
4. **Extra network adapters** (VPN, Hyper-V) making mDNS advertise the wrong IP.
5. **A third-party firewall** (ESET, Kaspersky, Bitdefender) with its own rules,
   independent of Windows Firewall. Every Windows check passes and the PC still
   never appears.
6. **A competing AirPlay receiver** already running and advertising.

Get the iPhone's IP from Settings → Wi-Fi → tap ⓘ next to the network.

### The phone can't join the PC's network (guest Wi-Fi)

If the iPhone is stuck on a guest SSID — client isolation, separate subnet — no
setting on the PC can bridge that. mDNS does not cross subnets.

**Use USB instead.** Personal Hotspot over a USB cable puts the phone and the PC
on one direct link and bypasses the router entirely:

1. Install **Apple Devices** from the Microsoft Store (this supplies the USB
   network driver).
2. Connect the iPhone by USB, unlock it, tap **Trust This Computer**.
3. iPhone → **Settings → Personal Hotspot → Allow Others to Join → ON**.
4. `.\doctor.ps1` — check 8 should now report the tether link as **Up**.
5. Start the receiver and mirror as usual.

This uses cellular data only for internet; the mirroring traffic stays on the
USB link, which is faster and more stable than Wi-Fi.

## Privacy notes

- Mirroring is a copy of the phone screen, so **incoming notifications appear
  in the mirror** — and to everyone watching it. Turn on a Focus / Do Not
  Disturb mode on the iPhone before presenting to a room or a call.
- **Require PIN** (the UI switch, or `-Pin` on the CLI) stops anyone else on
  the network from mirroring to your PC unchallenged.
- Nothing here phones home: no telemetry, no accounts. Logs and settings stay
  in `%LOCALAPPDATA%\pcairplay` on your machine.

## iOS compatibility

Open-source receivers work by making iOS fall back to the **"Legacy Protocol"**
built for the 3rd-gen Apple TV. No open-source project implements modern
AirPlay 2 mirroring.

| iOS | Status |
|---|---|
| 17 | ✅ Confirmed working |
| 18 | ✅ Working |
| 26 | ✅ Working |
| 27 | ⚠️ **At risk** — [UxPlay #535](https://github.com/FDH2/UxPlay/issues/535), unresolved |

On iOS 27 the phone appears to connect but never opens the data connection, so
no video arrives. If `doctor.ps1` passes every check and mirroring still fails
this way, check the iOS version — it may be an upstream protocol break rather
than anything local.

**Apple-DRM content (Apple TV+, Netflix) will not mirror** to any open-source
receiver. This is by design and can't be worked around.

## Ports

| Port | Proto | Purpose |
|---|---|---|
| 7000, 7001, 7100 | TCP | AirPlay control / RTSP / mirroring |
| 6000–6009 | UDP | RTP video, audio, timing |
| 5353 | UDP | mDNS discovery |

> **These are the ports the firewall rules cover, not the ports normally used.**
> Started without `-Port`, UxPlay lets the OS pick an *ephemeral* TCP port and
> publishes it via mDNS, so the fixed rules above cover nothing in normal
> operation. The program-scoped rule `PCAirPlay - uxplay.exe (any port)` created
> by `setup.ps1` is what actually permits inbound traffic — if the PC appears on
> the phone but never connects, check that rule first. Pass `-Port 7000` to force
> the fixed ports.

## Status

**Verified** on two Windows 11 PCs against UxPlay 1.72.1-3: full mirroring
sessions over home Wi-Fi and over USB tether (iPhone on iOS 26.5.2), hardware
H.264 decode active (`d3d11h264dec`), every tuned flag checked against
`uxplay -h`. `doctor.ps1`, `setup.ps1 -WhatIf`, `start-airplay.ps1 -DryRun` and
both `-SelfTest`s run clean end to end, and the UI and CLI produce identical
engine arguments for the same settings.

**CI**: every push runs the real `setup.ps1` flow on a clean GitHub runner —
upstream release lookup, download, SHA-256 verification, silent install,
firewall create and `-Uninstall` teardown — plus both `-SelfTest`s, the CLI
`-DryRun`, and a compile of the installer.

See [CLAUDE.md](CLAUDE.md) for the full breakdown, the first-run checklist, and
several gotchas found the hard way.

## Licence

MIT — see [LICENSE](LICENSE). This covers the scripts in this repo only.

It installs **UxPlay, which is GPL-3.0** and vendors a reverse-engineered
FairPlay implementation. Fine for personal use; worth understanding before
redistributing any bundle — which is why the installer here downloads UxPlay
from its own upstream release at install time instead of bundling it, and
ships nothing of Apple's.

*AirPlay, iPhone, Apple TV and Bonjour are trademarks of Apple Inc. This
project is not affiliated with, sponsored or endorsed by Apple.*
