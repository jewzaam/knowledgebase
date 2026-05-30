# Cross-Platform Python: Windows Quirks

Why `python` and `python3` invocations break on Windows and what mechanisms
intercept them.

> Prescriptive setup (PATH shims, install steps, `python -m <module>` rule)
> lives in [standards/python/cross-platform.md](https://github.com/jewzaam/standards/blob/main/python/cross-platform.md).

## Microsoft Store app execution aliases

On Windows, `python` and `python3` are intercepted by Microsoft Store app
execution aliases under `~\AppData\Local\Microsoft\WindowsApps`. These aliases
do not run Python — they open the Store. Scripts with `#!/usr/bin/env python3`
shebangs fail on Windows because the alias wins over any real Python
installation present elsewhere on `PATH`.

The Windows Python Launcher (`py -3`) is the correct way to invoke Python on
Windows, but it does not exist on Linux/macOS. This creates the split that
makes Makefiles and shell scripts need platform-conditional logic by default.

## Windows Smart App Control and pip entry-point .exe shims

On Windows 11, **Smart App Control (SAC)** silently blocks unsigned
pip-generated entry-point `.exe` launchers (e.g. `ai-guardian.exe` in
`%LOCALAPPDATA%\Python\pythoncore-*\Scripts\`).

**Symptom:** invoking the tool from bash returns `Permission denied` with exit
code **126**, even though the file has rwx and has no `Zone.Identifier`
alternate data stream.

**Cause:** the `.exe` is a small pip-generated stub with no Microsoft cloud
reputation. SAC blocks execution of unsigned binaries that lack established
trust, and pip-built entry-point launchers fall into that category.

**Confirm SAC is the cause:**

```powershell
Get-MpComputerStatus | Select-Object SmartAppControlState
```

If `SmartAppControlState` is `On`, SAC is enabled. SAC cannot be re-enabled
after being turned off, so disabling it is one-way and not a supported escape.

**The mechanism that works around it:** invoking the tool via its module entry
point — `python -m <module>` — bypasses the pip-generated `.exe` shim
entirely. The Python interpreter itself is signed by Microsoft and trusted by
SAC. The standards-side rule is to always use `python -m <module>` for this
reason.
