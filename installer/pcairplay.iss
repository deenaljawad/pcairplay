; pcairplay net-installer (Inno Setup 6).
;
; Deliberately installs ONLY the MIT-licensed scripts in this repo. The UxPlay
; engine (GPL-3.0, vendoring a reverse-engineered FairPlay implementation) is
; downloaded from its own upstream GitHub release at setup time by setup.ps1
; with a SHA-256 check, and Apple Bonjour cannot be redistributed at all -- so
; a full offline bundle is not an option, and this stays a thin installer on
; purpose. Nothing of Apple's and nothing GPL ships inside this exe.
;
; Built by .github/workflows/release.yml:
;     ISCC.exe /DMyAppVersion=<x.y.z> installer\pcairplay.iss
; Output lands in installer\Output\ (gitignored).

#ifndef MyAppVersion
  #define MyAppVersion "0.0.0-dev"
#endif
#define MyAppName "pcairplay"
#define MyAppURL  "https://github.com/gbulog/pcairplay"

[Setup]
; Fixed AppId so upgrades install over the top instead of side-by-side.
AppId={{6C87048D-4B16-49FF-93CC-75340B727AB2}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher=gbulog
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
DefaultDirName={autopf}\pcairplay
DefaultGroupName=pcairplay
DisableProgramGroupPage=yes
; "x64compatible" (Inno >= 6.3) rather than the removed-in-7.x "x64" alias.
ArchitecturesInstallIn64BitMode=x64compatible
; setup.ps1 needs Administrator (firewall rules, service checks), and it runs
; from [Run] below in the installer's context.
PrivilegesRequired=admin
MinVersion=10.0
LicenseFile=..\LICENSE
OutputBaseFilename=pcairplay-setup-{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayName={#MyAppName}
; The app icon, everywhere Windows shows one: the setup exe itself (what the
; user downloads), Apps & Features, and the shortcuts below.
SetupIconFile=..\pcairplay.ico
UninstallDisplayIcon={app}\pcairplay.ico

[Files]
Source: "..\uxplay-common.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\setup.ps1";         DestDir: "{app}"; Flags: ignoreversion
Source: "..\start-airplay.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\airplay-ui.ps1";    DestDir: "{app}"; Flags: ignoreversion
Source: "..\frame-mirror.ps1";  DestDir: "{app}"; Flags: ignoreversion
Source: "..\doctor.ps1";        DestDir: "{app}"; Flags: ignoreversion
Source: "..\AirPlay UI.vbs";    DestDir: "{app}"; Flags: ignoreversion
Source: "..\AirPlay UI.cmd";    DestDir: "{app}"; Flags: ignoreversion
Source: "..\Diagnostics.cmd";   DestDir: "{app}"; Flags: ignoreversion
Source: "..\Framed Mirror.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.md";         DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE";           DestDir: "{app}"; Flags: ignoreversion
Source: "..\pcairplay.ico";     DestDir: "{app}"; Flags: ignoreversion

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Icons]
; The .vbs launcher is the zero-window-flash path; .vbs shortcuts open via
; wscript by file association. IconFilename replaces the generic script icon;
; AppUserModelID matches what airplay-ui.ps1 sets on its process, so pinning
; and taskbar grouping treat this as one app rather than "PowerShell".
Name: "{group}\AirPlay UI";          Filename: "{app}\AirPlay UI.vbs";  WorkingDir: "{app}"; IconFilename: "{app}\pcairplay.ico"; AppUserModelID: "gbulog.pcairplay"
Name: "{group}\AirPlay Diagnostics"; Filename: "{app}\Diagnostics.cmd"; WorkingDir: "{app}"; IconFilename: "{app}\pcairplay.ico"
Name: "{group}\Uninstall pcairplay"; Filename: "{uninstallexe}"
Name: "{autodesktop}\AirPlay UI";    Filename: "{app}\AirPlay UI.vbs";  WorkingDir: "{app}"; IconFilename: "{app}\pcairplay.ico"; AppUserModelID: "gbulog.pcairplay"; Tasks: desktopicon

[Run]
; Interactive installs: keep the console open (-NoExit) so what setup did -
; the engine download, the Bonjour verdict, the firewall result - can actually
; be read. nowait, or that console would hold the installer open forever.
; runascurrentuser is REQUIRED: the postinstall flag implies runasoriginaluser
; (de-elevated), and setup.ps1 then refuses with "must run as Administrator"
; right at the finish line. Caught live on the first real install.
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -NoExit -File ""{app}\setup.ps1"""; Description: "Run first-time setup now (downloads the UxPlay engine)"; Flags: nowait postinstall skipifsilent runascurrentuser

; Silent installs (winget and friends): same setup, hidden and waited on, so a
; silent install still ends fully configured.
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\setup.ps1"""; Flags: runhidden waituntilterminated; Check: WizardSilent

[UninstallRun]
; Removes the firewall rules setup.ps1 created. UxPlay and Bonjour keep their
; own Apps & Features entries; setup.ps1 -Uninstall says so too.
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\setup.ps1"" -Uninstall"; Flags: runhidden waituntilterminated; RunOnceId: "RemovePCAirPlayFirewallRules"
