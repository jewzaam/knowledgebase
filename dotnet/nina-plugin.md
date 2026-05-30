# NINA 3.x Plugin Standards

Conventions for building, packaging, and publishing a C# NINA 3.x
(Nighttime Imaging 'N' Astronomy) plugin targeting the public
`NINA.Plugin` NuGet on .NET 8 Windows.

Derived from citation-backed research; this document is the standard
itself. Authoritative primary sources for every claim below: the
[NINA source](https://github.com/isbeorn/nina), the
[plugin template](https://github.com/isbeorn/nina.plugin.template), the
[`NINA.Plugin` NuGet package](https://www.nuget.org/packages/NINA.Plugin),
and the
[plugin manifest repository](https://github.com/isbeorn/nina.plugin.manifests)
(formerly `bitbucket.org/Isbeorn/nina.plugin.manifests`, now archived and
moved to GitHub).

For host-independent .NET conventions, see
[standards/dotnet/style.md](https://github.com/jewzaam/standards/blob/main/dotnet/style.md),
[standards/dotnet/project-structure.md](https://github.com/jewzaam/standards/blob/main/dotnet/project-structure.md),
and [standards/dotnet/testing.md](https://github.com/jewzaam/standards/blob/main/dotnet/testing.md).

## Quick-reference

| Aspect | Standard |
|---|---|
| TFM | `net8.0-windows` (NINA 3.2 stable). Bump only when `NINA.Plugin` does. |
| Platform | x64 |
| `UseWPF` | `true` when the plugin includes XAML |
| NuGet | `NINA.Plugin <matching-version>` only; rely on transitive deps |
| `MinimumApplicationVersion` | Matches the `NINA.Plugin` NuGet version |
| Install root | `%LOCALAPPDATA%\NINA\Plugins\<api-version>\<title>\` |
| `<api-version>` segment | **3-part**, currently `3.0.0` for all NINA 3.x |
| Plugin class | `[Export(typeof(IPluginManifest))] : PluginBase` |
| Constructor | `[ImportingConstructor]` exactly once per class |
| Persisted options | `new PluginOptionsAccessor(profileService, Guid.Parse(this.Identifier))` |
| Options UI key | `<AssemblyTitle>_Options` |
| ResourceDictionary code-behind | `[Export(typeof(ResourceDictionary))] partial class : ResourceDictionary` |
| RelayCommand | `CommunityToolkit.Mvvm.Input.RelayCommand` (NINA's own is `[Obsolete]`) |
| Logger backend | Serilog (NOT log4net); static `NINA.Core.Utility.Logger` |
| Embedded HTTP | `EmbedIO 3.5.2` with `HttpListenerMode.EmbedIO` |
| Cleanup | Override `Task Teardown()`; unsubscribe / unregister; `base.Teardown()` last |
| Publishing | PR to `github.com/isbeorn/nina.plugin.manifests`; `manifest.json` per schema |
| Hash | SHA-256 over the installer file; recomputed if DLL changes |

## 1. Project layout and csproj

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0-windows</TargetFramework>
    <Platforms>x64</Platforms>
    <PlatformTarget>x64</PlatformTarget>
    <OutputType>Library</OutputType>
    <UseWPF>true</UseWPF>
    <CopyLocalLockFileAssemblies>true</CopyLocalLockFileAssemblies>
    <LangVersion>latest</LangVersion>
  </PropertyGroup>

  <ItemGroup>
    <!-- NINA.Plugin version matches the target NINA stable.
         3.2.0.9001 for NINA 3.2 stable. -->
    <PackageReference Include="NINA.Plugin" Version="3.2.0.9001">
      <PrivateAssets>all</PrivateAssets>
    </PackageReference>
    <!-- third-party PackageReferences here -->
  </ItemGroup>

  <Target Name="DeployToNinaPlugins" AfterTargets="Build">
    <PropertyGroup>
      <PluginDir>$(LocalAppData)\NINA\Plugins\3.0.0\$(AssemblyTitle)\</PluginDir>
    </PropertyGroup>
    <MakeDir Directories="$(PluginDir)" Condition="!Exists('$(PluginDir)')" />
    <Copy SourceFiles="$(TargetPath)" DestinationFolder="$(PluginDir)" />
    <!-- copy third-party DLLs the plugin brings — NOT NINA-shipped -->
  </Target>
</Project>
```

Rules:

- `net8.0-windows` matches the running NINA 3.2 host. NINA 3.3+ may bump
  to `net10.0-windows`; track whatever `NINA.Plugin` ships.
- Reference `NINA.Plugin` only and rely on transitive resolution. Do not
  pull `NINA.Core`, `NINA.Equipment`, etc. as direct package references
  unless a specific reason applies.
- `PrivateAssets=all` keeps NINA's own DLLs out of the published plugin
  folder (NINA already ships them — see §2).
- The install path's `<api-version>` is the **3-segment** `3.0.0`, not
  the 4-segment `3.0.0.9001` package version. All NINA 3.x plugins
  install under `\NINA\Plugins\3.0.0\` regardless of the running NINA
  build.
- The VS post-build editor mangles `%localappdata%` tokens to
  `%25localappdata%25`. Either author the `<Target>` directly in XML as
  shown, or fix the encoding after the wizard touches the file.
- The plugin template's checked-in csproj still targets .NET Framework
  4.8 for historical reasons — ignore it. The VS wizard generates a
  `net8.0-windows` project.
- **Build output path depends on whether you build the sln or the
  csproj.** With `<Platforms>x64</Platforms>` set, `dotnet build -c
  Release` against the `.sln` resolves the `Release|x64` solution
  configuration and emits to `bin\x64\Release\`. Building the `.csproj`
  directly (no sln in cwd) emits to `bin\Release\`. Local builds and CI
  typically diverge on this — pin scripts (install, package, ship-list
  selection) to `bin\x64\Release` and always drive builds through the
  sln so CI and local agree.

## 2. Do not bundle host-shipped assemblies

NINA isolates plugins via `AssemblyLoadContext`, but the plugin still
resolves shared types through its own context first. Bundling an
assembly NINA already ships causes either a second copy (breaking
cross-context type identity) or a version mismatch surfacing as
`TypeLoadException` / `MissingMethodException`.

Do not copy any of these into the plugin folder:

```text
NINA.Astrometry, NINA.Core, NINA.Equipment, NINA.Image,
NINA.PlateSolving, NINA.Profile, NINA.Sequencer, NINA.WPF.Base,
NINA.CustomControlLibrary,
CommunityToolkit.Mvvm, Newtonsoft.Json,
Serilog, Serilog.Sinks.File, Serilog.Sinks.Console,
System.ComponentModel.Composition, OxyPlot.Core,
SQLite (SourceGear.sqlite3 / System.Data.SQLite),
gRPC, Google.Protobuf, Accord.Math
```

For each third-party package the plugin pulls in that is **not** on the
list, add an explicit `<Copy>` element in the `DeployToNinaPlugins`
target.

**NINA does not ship log4net.** Logging is Serilog under the hood.
Anything online that mentions log4net for NINA is out of date.

## 3. AssemblyInfo.cs — the manifest source of truth

`PluginBase` reads `IPluginManifest` data from assembly attributes:

| Status | Attribute | Maps to |
|---|---|---|
| **Required** | `[Guid("...")]` | `Identifier` |
| **Required** | `[AssemblyTitle("...")]` | `Name` (drives DataTemplate key, install folder, manifest Name) |
| **Required** | `[AssemblyVersion("M.m.p.b")]` | (CLR identity) |
| **Required** | `[AssemblyFileVersion("M.m.p.b")]` | `Version` |
| **Required** | `[AssemblyDescription("...")]` | `Descriptions.ShortDescription` |
| Recommended | `[AssemblyCompany("...")]` | `Author` |
| Recommended | `[AssemblyMetadata("License", "...")]` | `License` |
| Recommended | `[AssemblyMetadata("LicenseURL", "...")]` | `LicenseURL` |
| Recommended | `[AssemblyMetadata("Repository", "...")]` | `Repository` |
| Recommended | `[AssemblyMetadata("MinimumApplicationVersion", "3.2.0.9001")]` | `MinimumApplicationVersion` |
| Optional | `[AssemblyMetadata("Homepage", "...")]` | `Homepage` |
| Optional | `[AssemblyMetadata("ChangelogURL", "...")]` | `ChangelogURL` |
| Optional | `[AssemblyMetadata("Tags", "a, b, c")]` | `Tags` (string array; comma-separated) |
| Optional | `[AssemblyMetadata("LongDescription", "...")]` | `Descriptions.LongDescription` |
| Optional | `[AssemblyMetadata("FeaturedImageURL", "...")]` | `Descriptions.FeaturedImageURL` |
| Optional | `[AssemblyMetadata("ScreenshotURL", "...")]` | `Descriptions.ScreenshotURL` |
| Optional | `[AssemblyMetadata("AltScreenshotURL", "...")]` | `Descriptions.AltScreenshotURL` |

Notes:

- The plugin manifest README documents a `[AssemblyMetadata("ShortDescription", ...)]`
  framing, but `PluginBase` actually reads the standard
  `[AssemblyDescription(...)]` attribute. Set both consistently: a
  substantive `[AssemblyTitle]` and a clean `[AssemblyDescription]` that
  match.
- `AssemblyVersion` segments are 16-bit unsigned (`0`–`65535`). Always
  emit 4 segments.
- Defaults when missing: `Version` → `1.0.0.0`,
  `MinimumApplicationVersion` → `1.11.0.0`. Both are accepted by
  `PluginLoader` but rejected by manifest-repo validation. Treat
  unspecified versions as a hard error.
- Missing `[Guid]`: `PluginOptionsAccessor.GetAssemblyGuid` returns
  `null`, options cannot persist, and identity tracking breaks. Set the
  GUID once and never change it.

A canonical template is in [Appendix A](#appendix-a-canonical-assemblyinfo).

## 4. The main plugin class — MEF wiring

```csharp
[Export(typeof(IPluginManifest))]
public class MyPlugin : PluginBase, INotifyPropertyChanged {
    private readonly IProfileService profileService;
    private readonly IImageSaveMediator imageSaveMediator;
    private readonly IPluginOptionsAccessor pluginSettings;

    [ImportingConstructor]
    public MyPlugin(IProfileService profileService,
                    IImageSaveMediator imageSaveMediator) {
        this.profileService = profileService;
        this.imageSaveMediator = imageSaveMediator;
        this.pluginSettings = new PluginOptionsAccessor(
            profileService, Guid.Parse(this.Identifier));

        profileService.ProfileChanged += OnProfileChanged;
        imageSaveMediator.BeforeImageSaved += OnBeforeImageSaved;
    }

    public override async Task Teardown() {
        profileService.ProfileChanged -= OnProfileChanged;
        imageSaveMediator.BeforeImageSaved -= OnBeforeImageSaved;
        await base.Teardown();
    }

    private void OnProfileChanged(object sender, EventArgs e) {
        RaisePropertyChanged(nameof(SomeProfileSpecificProperty));
    }

    private async Task OnBeforeImageSaved(object sender, BeforeImageSavedEventArgs e) {
        // mutate FITS headers here
    }

    public event PropertyChangedEventHandler PropertyChanged;
    protected void RaisePropertyChanged([CallerMemberName] string name = null)
        => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
}
```

Rules:

- Exactly **one** `[Export(typeof(IPluginManifest))]` per plugin
  assembly.
- Exactly **one** `[ImportingConstructor]` per class. The default MEF
  `CreationPolicy` is `Shared` (singleton per container) and the plugin
  manager relies on this — do not declare `[PartCreationPolicy(NonShared)]`
  on the manifest class.
- Inject only what the plugin needs.
- Do not access `ISequenceMediator` in the constructor body — it is not
  initialized until after all plugins are loaded. Defer to
  `Initialize()`.
- `PluginBase` provides virtual async `Initialize()` and `Teardown()`
  returning `Task.CompletedTask`. Override one or both as needed.
- `PluginBase` does **not** extend `BaseINPC` and does **not** implement
  `IDisposable`. `Teardown()` is the only cleanup hook. Implement INPC
  on the plugin class directly (as above) or compose with a separate
  view-model.

## 5. Mediators and device consumers

Two interaction patterns.

### 5.1 Event subscription

For discrete actions:

| Mediator | Notable events |
|---|---|
| `IImagingMediator` | `ImagePrepared(ImagePreparedEventArgs)` — **NOT** `ImageSaved` |
| `IImageSaveMediator` | `BeforeImageSaved(Func<obj, BeforeImageSavedEventArgs, Task>)`, `BeforeFinalizeImageSaved(Func<obj, BeforeFinalizeImageSavedEventArgs, Task>)`, `ImageSaved(EventHandler<ImageSavedEventArgs>)` |
| `ITelescopeMediator` | `BeforeMeridianFlip`, `AfterMeridianFlip`, `Parked`, `Homed`, `Unparked`, `Slewed` |
| Other device mediators | Similar per-action event pattern |

- The `Func<..., Task>` events on `IImageSaveMediator` are **awaited** by
  the publisher. Implement these as `async Task` methods. Returning
  `async void` silently drops the await.
- The fire-and-forget `EventHandler<ImageSavedEventArgs>` (`ImageSaved`)
  is the case where `async void` is the only delegate-compatible option
  — wrap the entire body in `try / catch { Logger.Error(ex); }` because
  unhandled exceptions from `async void` propagate to the UI
  `SynchronizationContext` and can crash NINA.
- `BeforeFinalizeImageSaved` cannot mutate FITS headers — the changes
  are not reflected in the written file. Use `BeforeImageSaved` for that
  work.

### 5.2 Device-consumer registration

For streaming device-state polls:

```csharp
public class MyPlugin : PluginBase, ITelescopeConsumer {
    [ImportingConstructor]
    public MyPlugin(ITelescopeMediator telescopeMediator) {
        this.telescopeMediator = telescopeMediator;
        telescopeMediator.RegisterConsumer(this);
    }

    public void UpdateDeviceInfo(TelescopeInfo info) {
        // called on the hardware poll thread
    }

    public override Task Teardown() {
        telescopeMediator.RemoveConsumer(this);
        return base.Teardown();
    }
}
```

Note: the API verb is `RemoveConsumer`, not `Unregister`.

### 5.3 Thread semantics

Mediator events and `UpdateDeviceInfo` callbacks fire on background
threads in the general case. Plugin code that touches UI-bound
properties must marshal via `Dispatcher.InvokeAsync` — see
[standards/dotnet/style.md § UI marshalling](https://github.com/jewzaam/standards/blob/main/dotnet/style.md#ui-marshalling-wpf).

### 5.4 Cleanup discipline

- Every `+= handler` requires a paired `-= handler` in `Teardown()`.
- Every `RegisterConsumer(this)` requires a paired `RemoveConsumer(this)`.
- **Never** subscribe with an anonymous lambda — there is no
  equal-delegate-instance match for unsubscription. Always use a named
  method or store the delegate in a field.

## 6. Options UI (WPF)

### 6.1 The DataTemplate key

NINA renders the plugin's options panel by resolving:

```csharp
Application.Current.Resources[plugin.Name + "_Options"]
```

`plugin.Name` is `IPluginManifest.Name`, auto-populated from
`[AssemblyTitle]`. The constant `DataTemplatePostfix.Options` is
`"_Options"`.

With `[assembly: AssemblyTitle("MyPlugin")]` the DataTemplate must be
keyed `x:Key="MyPlugin_Options"`.

### 6.2 Wiring

`Options.xaml`:

```xml
<ResourceDictionary
    x:Class="MyPlugin.Options"
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
    <DataTemplate x:Key="MyPlugin_Options">
        <StackPanel DataContext="{Binding}" Orientation="Vertical">
            <!-- bindings against plugin class properties -->
        </StackPanel>
    </DataTemplate>
</ResourceDictionary>
```

`Options.xaml.cs`:

```csharp
using System.ComponentModel.Composition;
using System.Windows;

namespace MyPlugin {
    [Export(typeof(ResourceDictionary))]
    partial class Options : ResourceDictionary {
        public Options() { InitializeComponent(); }
    }
}
```

`[Export(typeof(ResourceDictionary))]` is what tells `PluginLoader` to
merge the dictionary into `Application.Current.Resources.MergedDictionaries`.
Forgetting it produces an empty options pane.

DataContext inside the template is the `IPluginManifest` instance
itself (the `PluginBase` subclass).

### 6.3 Other DataTemplate postfixes

| Postfix | Key form | Purpose |
|---|---|---|
| `_Options` | `<IPluginManifest.Name>_Options` | Plugin global options panel |
| `_Mini` | `<FullyQualifiedTypeName>_Mini` | Compact sequencer item view |
| `_Dockable` | `<FullyQualifiedTypeName>_Dockable` | Dockable imaging-tab panel |
| `_<DeviceType>Settings` | `<FullyQualifiedTypeName>_CameraSettings`, etc. | Custom device-driver settings |

### 6.4 Themed styles

NINA's themed brushes and styles are merged into
`Application.Current.Resources` at app startup. Reference via
`{StaticResource ...}` without merging anything additional in the plugin
dictionary.

There is **no** `BorderedTextBlock` style — wrap a `TextBlock` (with the
`StandardTextBlock` style) in a `Border`.

### 6.5 RelayCommand

`NINA.Core.Utility.RelayCommand` is `[Obsolete]`. Use
`CommunityToolkit.Mvvm.Input.RelayCommand` / `AsyncRelayCommand`. NINA
ships `CommunityToolkit.Mvvm 8.4.0`, so:

```xml
<PackageReference Include="CommunityToolkit.Mvvm" Version="8.4.0">
  <ExcludeAssets>runtime</ExcludeAssets>
</PackageReference>
```

`ExcludeAssets=runtime` keeps compile-time references but suppresses
publishing the DLL (NINA already ships it).

## 7. Persisted options — IPluginOptionsAccessor

Construct in the plugin constructor:

```csharp
this.pluginSettings = new PluginOptionsAccessor(
    profileService, Guid.Parse(this.Identifier));
```

The GUID **must** match `[assembly: Guid(...)]`. Defensive form for the
case where the attribute is missing or duplicated:

```csharp
var guid = PluginOptionsAccessor.GetAssemblyGuid(typeof(MyOptions))
    ?? throw new Exception("GUID was not found in assembly metadata");
this.pluginSettings = new PluginOptionsAccessor(profileService, guid);
```

### 7.1 Typed accessors

Typed `GetValueT(name, default)` / `SetValueT(name, value)` pairs exist
for:

`Boolean, Byte, SByte, Char, Decimal, Double, Single, Int32, UInt32,
Int64, UInt64, Int16, UInt16, String, DateTime, Guid, Color, Enum<T>`

Naming follows CLS type names: `GetValueSingle`, not `GetValueFloat`.
Color is stored as an ARGB integer. Enums are stored as strings via
`Enum.GetName` and parsed back with `Enum.TryParse<T>` — **renaming an
enum member silently breaks deserialization** for existing profiles.
Treat enum-member renames as a versioned change requiring migration.

### 7.2 Profile scope

All settings are **per-profile**. Storage is
`profileService.ActiveProfile.PluginSettings`, an in-memory
`Dictionary<Guid, IDictionary<string, object>>` namespaced by plugin
GUID. Two plugins with the same setting name do not collide because
they have different GUIDs.

Profile files live at `%LOCALAPPDATA%\NINA\Profiles\<profile-guid>.profile`
and are serialized via `DataContractSerializer`. `Profile.Save()` uses a
journal → backup → final three-file write for crash safety.

### 7.3 Profile-change handling

Subscribe to `IProfileService.ProfileChanged` and re-raise PropertyChanged
notifications when the active profile switches; otherwise the UI shows
stale values from the previous profile:

```csharp
profileService.ProfileChanged += (s, e) => RaisePropertyChanged(nameof(MySetting));
```

Unsubscribe in `Teardown()`.

### 7.4 Convention: use `nameof()` for keys

```csharp
public bool EnableX {
    get => pluginSettings.GetValueBoolean(nameof(EnableX), defaultValue: true);
    set { pluginSettings.SetValueBoolean(nameof(EnableX), value); RaisePropertyChanged(); }
}
```

No magic strings. Refactor-safe.

## 8. Embedded HTTP servers

Plugins that expose HTTP endpoints (REST APIs, Prometheus metrics, local
UI servers) **must** use EmbedIO with `HttpListenerMode.EmbedIO` to
avoid the http.sys URL-ACL admin requirement.

```csharp
private CancellationTokenSource serverToken;
private Thread serverThread;

public void StartServer() {
    serverToken = new CancellationTokenSource();
    serverThread = new Thread(() => {
        using var server = new WebServer(o => o
            .WithUrlPrefix($"http://*:{Port}")
            .WithMode(HttpListenerMode.EmbedIO));
        server.WithWebApi("/api", m => m.WithController<MyController>());
        server.RunAsync(serverToken.Token).Wait();
    }) { Name = "MyPlugin HTTP", IsBackground = true };
    serverThread.Start();
}

public void StopServer() => serverToken?.Cancel();
```

Why this pattern:

- `HttpListenerMode.EmbedIO` bypasses http.sys by binding raw managed
  TCP sockets. No admin, no `netsh urlacl`, no firewall warning at
  startup (only at first external connection).
- A dedicated named `Thread` gives the debugger a useful identifier.
  `IsBackground = true` lets it die at process exit.
- `serverToken.Cancel()` is registered on the listener and unblocks
  `.Wait()` cleanly.

NuGet: `EmbedIO 3.5.2`, targets `.NETStandard 2.0`, no version conflicts
with NINA's other dependencies.

Port selection: a fixed user-configurable port with fallback via
`CoreUtil.GetNearestAvailablePort(port)`. Expose `Port` (configured) and
`CachedPort` (actually bound) properties so the user can see which port
was used when the configured one was taken.

Do **not** use `HttpListenerMode.Microsoft` — that path requires
elevation or `netsh http add urlacl` to bind any prefix other than
`http://localhost:port/`.

## 9. Logging

Backend is **Serilog**, not log4net. Use `NINA.Core.Utility.Logger` as a
static class.

```csharp
Logger.Info("Server started on port " + port);
Logger.Warning("Configured port unavailable; bound " + cachedPort);
try { ... } catch (Exception ex) { Logger.Error(ex, "Server failed to start"); }

if (Logger.IsEnabled(LogLevelEnum.Trace)) {
    Logger.Trace($"State dump: {ExpensiveDump()}");
}
```

- Methods: `Error`, `Warning`, `Info`, `Debug`, `Trace`,
  `SetLogLevel(LogLevelEnum)`, `IsEnabled(LogLevelEnum)`, `CloseAndFlush()`.
- `Error` overloads: `(Exception)`, `(Exception, string)`, `(string)`.
  The Exception-taking overload preserves the stack trace — prefer it.
- `[CallerMemberName]`, `[CallerFilePath]`, `[CallerLineNumber]` optional
  params are auto-supplied — don't pass them.
- Log file:
  `%LOCALAPPDATA%\NINA\Logs\<timestamp>-<version>.<processId>-.log`,
  monthly rolling, 90-day retention, 1-second flush.
- Line format:
  `{Timestamp:yyyy-MM-ddTHH:mm:ss.ffff}|{LegacyLogLevel}|{Message:lj}{NewLine}{Exception}`

Level discipline:

| Level | Use |
|---|---|
| `Trace` | High-frequency hot-path; off by default; gate with `IsEnabled` |
| `Debug` | Internal state useful during bug reproduction |
| `Info` | Lifecycle events (server started, settings loaded) |
| `Warning` | Recoverable anomaly |
| `Error` | Operation failed; always include the exception |

NINA does **not** auto-prefix the plugin name. Heavy-logging plugins
maintain their own separate log file in
`%LOCALAPPDATA%\NINA\<PluginName>\Logs\` and use a per-plugin prefix.
This is a pattern, not a framework affordance.

Never log credentials, API keys, tokens, or PII. Log files persist 90
days and are shared during support.

## 10. Publishing

Manifest PR target: `https://github.com/isbeorn/nina.plugin.manifests`. The
former Bitbucket repo `bitbucket.org/Isbeorn/nina.plugin.manifests` is
archived; do not open PRs there. Schema authority is `manifest.schema.json`
at the GitHub repo root.

### 10.1 Schema (selected required fields)

```json
{
  "Name": "MyPlugin",
  "Identifier": "78fc6455-c1ba-4dc5-a8d0-9f48aecd733d",
  "Author": "Your Name",
  "License": "Apache-2.0",
  "LicenseURL": "https://www.apache.org/licenses/LICENSE-2.0",
  "Repository": "https://github.com/you/myplugin",
  "Version": { "Major": 1, "Minor": 0, "Patch": 0, "Build": 0 },
  "MinimumApplicationVersion": { "Major": 3, "Minor": 2, "Patch": 0, "Build": 9001 },
  "Installer": {
    "URL": "https://github.com/you/myplugin/releases/download/v1.0.0/MyPlugin.zip",
    "Type": "ARCHIVE",
    "Checksum": "abc123...",
    "ChecksumType": "SHA256"
  },
  "Descriptions": {
    "ShortDescription": "..."
  }
}
```

Optional manifest fields: `ChangelogURL`, `Tags`, `Homepage`,
`LongDescription`, `FeaturedImageURL`, `ScreenshotURL`,
`AltScreenshotURL`, `Channel ("Beta")`.

### 10.2 GUID matching

The same GUID lives in four places and must agree exactly:

1. `[assembly: Guid("...")]` in `AssemblyInfo.cs`
2. `IPluginManifest.Identifier` (auto-derived from #1 via `PluginBase`)
3. `manifest.json` `"Identifier"`
4. The GUID passed to `new PluginOptionsAccessor(...)`

The GUID **must never change across versions** — it is the
install/uninstall identity.

### 10.3 SHA-256 over the installer

The checksum is computed over the file referenced by `Installer.URL`:

- `Installer.Type = "DLL"` → hash of the `.dll`
- `Installer.Type = "ARCHIVE"` → hash of the `.zip`

**Recompiling after manifest creation invalidates the checksum.** In
CI, the build → hash → manifest sequence must be one transactional
workflow.

### 10.4 MinimumApplicationVersion

Match the `NINA.Plugin` NuGet version the plugin was compiled against.
Compiled against `NINA.Plugin 3.2.0.9001` → manifest declares
`MinimumApplicationVersion = {3, 2, 0, 9001}`.

### 10.5 Folder structure

On the GitHub-hosted manifest repo:

```text
manifests/<first-letter-lower>/<Plugin Name>/<X.Y.Z[.B]>/manifest.json
```

Example: `manifests/p/PixInsightTools/1.0.0/manifest.json`. The first-letter
segment is lowercase; the plugin-name segment preserves the title casing
matching `[AssemblyTitle]`; the version segment is the 3- or 4-segment plugin
version (no NINA-version segment in the path).

### 10.6 Channels

`"Channel": "Beta"` → beta channel. Users opt in via NINA
Options > General > Plugin Repositories with URL
`https://nighttime-imaging.eu/wp-json/nina/v1/beta`. Omit `Channel` for
stable. There are no Nightly or Alpha channels at the manifest layer.

### 10.7 Validation before PR

```bash
winget install nodejs
npm install
node gather.js
```

The manifest must validate cleanly against `manifest.schema.json` before
opening the PR.

### 10.8 Recommended automation

Wire the official GitHub Actions template (`./tools/github-action.yml`
in the manifest repo) to fire on a version-tag push. It builds, hashes,
generates the manifest, and opens the PR in one workflow — eliminating
the recompile-invalidates-hash trap.

## 11. Pitfalls — do-not list

1. **Do not** bundle NINA-shipped assemblies in the plugin output folder
   (§2).
2. **Do not** use the obsolete `NINA.Core.Utility.RelayCommand` — use
   `CommunityToolkit.Mvvm.Input.RelayCommand` (§6.5).
3. **Do not** subscribe with anonymous lambdas — cannot unsubscribe;
   named methods only (§5.4).
4. **Do not** leave `async void` handler bodies unwrapped — always
   `try / catch` and log (§5.1).
5. **Do not** look for `ImageSaved` on `IImagingMediator` — it lives on
   `IImageSaveMediator` (§5.1).
6. **Do not** mutate FITS headers in `BeforeFinalizeImageSaved` — the
   changes are not reflected; use `BeforeImageSaved` (§5.1).
7. **Do not** access `ISequenceMediator` in `[ImportingConstructor]` —
   defer to `Initialize()` (§4).
8. **Do not** use `HttpListenerMode.Microsoft` — requires admin / netsh
   (§8).
9. **Do not** introduce a parallel logging framework — go through
   `NINA.Core.Utility.Logger` (§9).
10. **Do not** change the plugin GUID across versions — breaks install
    identity (§10.2).
11. **Do not** recompile after manifest generation — invalidates the
    SHA-256 (§10.3).
12. **Do not** use `Dispatcher.BeginInvoke` — use `Dispatcher.InvokeAsync`
    ([standards/dotnet/style.md](https://github.com/jewzaam/standards/blob/main/dotnet/style.md)).
13. **Do not** rename enum members exposed via `GetValueEnum<T>` —
    silently breaks deserialization (§7.1).
14. **Do not** trust the install-folder `<api-version>` to be 4-segment
    — it is the 3-segment `3.0.0` (§1).

## Appendix A — Canonical AssemblyInfo

```csharp
using System.Reflection;
using System.Runtime.InteropServices;

[assembly: AssemblyTitle("MyPlugin")]
[assembly: AssemblyDescription("Short one-line description (shows in plugin manager)")]
[assembly: AssemblyCompany("Your Name")]
[assembly: AssemblyProduct("MyPlugin")]
[assembly: AssemblyCopyright("Copyright © 2026")]
[assembly: ComVisible(false)]
[assembly: Guid("00000000-0000-0000-0000-000000000000")]   // do not change after first release
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

[assembly: AssemblyMetadata("License", "Apache-2.0")]
[assembly: AssemblyMetadata("LicenseURL", "https://www.apache.org/licenses/LICENSE-2.0")]
[assembly: AssemblyMetadata("Repository", "https://github.com/you/myplugin")]
[assembly: AssemblyMetadata("Homepage", "https://github.com/you/myplugin")]
[assembly: AssemblyMetadata("ChangelogURL", "https://github.com/you/myplugin/releases")]
[assembly: AssemblyMetadata("MinimumApplicationVersion", "3.2.0.9001")]
[assembly: AssemblyMetadata("Tags", "imaging, automation")]
[assembly: AssemblyMetadata("LongDescription", "Longer multi-paragraph description.")]
[assembly: AssemblyMetadata("FeaturedImageURL", "https://example.com/featured.png")]
[assembly: AssemblyMetadata("ScreenshotURL", "https://example.com/screenshot.png")]
```

## Appendix B — Audit checklist

When auditing a plugin against this standard:

1. **csproj**: `net8.0-windows`, `x64`, `UseWPF=true`, single
   `NINA.Plugin` package reference, post-build deploys to
   `\NINA\Plugins\3.0.0\<Title>\`, does **not** copy NINA-shipped DLLs.
2. **AssemblyInfo.cs**: required and recommended `[AssemblyMetadata]`
   keys present; `MinimumApplicationVersion` matches `NINA.Plugin`
   version; `[Guid]` set.
3. **Main plugin class**: `[Export(typeof(IPluginManifest))]`, single
   `[ImportingConstructor]`, every `+=` paired with a `-=` in
   `Teardown()`.
4. **Options UI** (when present): `Options.xaml.cs` has
   `[Export(typeof(ResourceDictionary))]`; DataTemplate key matches
   `<AssemblyTitle>_Options`.
5. **Persisted settings** (when present): constructs
   `PluginOptionsAccessor` with the assembly GUID; subscribes to
   `IProfileService.ProfileChanged` and unsubscribes in `Teardown()`.
6. **HTTP server** (when present): EmbedIO with
   `HttpListenerMode.EmbedIO`, dedicated named thread, `CancellationToken`
   stop pattern.
7. **Logging**: all calls go through `NINA.Core.Utility.Logger`. No
   log4net, no direct Serilog, no `Console.WriteLine`.
8. **Publishing artifacts**: `manifest.json` matches the published
   schema; `Installer.ChecksumType = "SHA256"`; `Identifier` matches
   `[Guid]`.
