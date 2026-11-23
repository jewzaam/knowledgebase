# Windows 11 Home and PowerShell 5.1 Facts

Tested on a Windows 11 Home laptop.

## Windows 11 Home

- No Windows Sandbox, no Hyper-V, and no RDP server.
- `conhost.exe --headless <cmd>` runs a console program with no window. A Task
  Scheduler action using `powershell -WindowStyle Hidden` still flashes a
  console.
- `whisper-cli.exe` exits with `0xC0000135` on a fresh Windows until the Visual
  C++ runtime is installed (winget `Microsoft.VCRedist.2015+.x64`).
- Sysinternals Autologon stores the password as an encrypted LSA secret.
  Windows Hello-only sign-in (`DevicePasswordLessBuildVersion=2`) must be set to
  0 for automatic sign-in (community sources, not an official page).

## whisper.cpp on Windows

- Prebuilt Windows binaries come with the numbered `b<NNNN>` releases;
  version-tagged releases can carry no assets.
- The `base.en` model is about 141 MB and transcribed 23 s of speech in 7 to 15
  s on a laptop CPU.

## PowerShell 5.1 behaviors

- `Process.ExitCode` is empty after `WaitForExit(ms)` unless the `Handle`
  property was touched first.
- git's stderr output (CRLF warnings) aborts a script under
  `$ErrorActionPreference = 'Stop'`.
- `-match` is case-insensitive.
- `Set-Content -Encoding utf8` writes a BOM.
- A function named `r` is shadowed by the `Invoke-History` alias.
