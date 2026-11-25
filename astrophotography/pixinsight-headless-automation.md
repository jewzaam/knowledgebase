# PixInsight headless automation (PJSR) and RC-Astro

How PixInsight 1.9.6 (Windows) behaves when driven by scripts instead of the GUI, as observed while building an agent-run processing pipeline on a CPU-only laptop. Facts only; where a number is a measurement it is from one machine (4 logical cores, 12 GB RAM, Intel HD 5500, no GPU).

## Running a script without the GUI

- `PixInsight.exe -n=<slot> --automation-mode --no-startup-scripts --no-startup-check-updates --no-startup-gui-messages --run=<script.js> --force-exit` runs a PJSR script and exits. The flags were found in a third-party wrapper, not in vendor documentation; they worked on 1.9.6. A GUI instance can stay open alongside a headless one.
- `<slot>` selects the settings file: slot 1 is `%APPDATA%\Pleiades\core-001-pxi.settings`, slot 2 is `core-002-pxi.settings`. Settings are XML. A fresh slot has none of the GUI instance's process preferences, so Gaia/APASS database paths (`ModuleData/Gaia/DR3DatabaseFilePathNN`, `DR3SPDatabaseFilePathNN`, `ModuleData/APASS/...`) must be copied in (merge only those nodes; copying the whole slot-1 file made the RC-Astro module disappear in slot 2).
- Script `console` output does not reach stdout. Log to a file from the script.
- A script that throws before its own try/catch exits with code 0 and no message. Wrap everything, and write a log line first.
- `File.openForWriting` on an existing path followed by `seekEnd` failed silently for appending; create one new log file per run instead. A file PixInsight holds open for writing cannot be read from outside until the process exits.
- `ImageWindow.open(path)` (first element of the returned array), `view.beginProcess()` / `endProcess()`, `Image.cropBy(-l, -t, -r, -b)` (negative = remove pixels) and `window.saveAs(path, false, false, false, false)` worked. The `Crop` process object raised a bare `Error` from `executeOn` on a solved image.
- `#define` constants from `pjsr/*.jsh` headers are preprocessor macros, not variables: they exist in the script text only after preprocessing. Code loaded with `eval` at run time sees none of them. Substituting their values into the text first works. `UndoFlag_NoSwapFile` is not a usable name in `beginProcess`; call `beginProcess()` without it.
- A run folder that already exists from an earlier run caused a rerun with the same output id to do nothing and exit 0.

## Using shipped scripts without their dialogs

The Canon Banding Reduction script (`src/scripts/CanonBandingReduction/CanonBandingReduction.js`) exposes a `BandingEngine` with `setAmount`, `setHighlightProtect(bool, sigma)`, `setTargetImage`, `doit(view)`. Loading it headless means reading the file, dropping every preprocessor line (including backslash-continued `#feature-info` blocks), removing the trailing `main();`, supplying its `#define`d names (`DEBUGGING_MODE_ON`, `TITLE`, `VERSION`) and the header macros, then `eval`. It flattens per-row medians (horizontal banding). Applied to a stacked linear starless image it changed the noise estimate by only 2-3 %; the benefit shows after a hard stretch.

## Process parameter discovery

`for (var k in new SomeProcess)` lists the parameters and defaults. Useful findings (1.9.6):

- `SpectrophotometricColorCalibration`: `catalogId` defaults to `GaiaDR3SP`; `executeOn(view)` returns false (no error) when the solved image has no Gaia DR3/SP database configured. Needs an astrometric solution in the file.
- `BlurXTerminator`, `NoiseXTerminator`, `StarXTerminator` (RC-Astro suite 2.6.11 via repository `https://www.rc-astro.com/PixInsight`): parameters such as `sharpen_stars`, `sharpen_nonstellar`, `denoise`, `detail`, `enable_color_separation`, `denoise_color`, `stars`, `unscreen`. They run on CPU headless. Measured: BlurX 5 min on a 12 MP colour image, 14-16 min on a 24 MP mono image; NoiseX 12-16 min per 24 MP mono channel; StarX 8-10 min. After licensing, no dialog blocked the headless run.
- `MultiscaleMedianTransform.layers` is an array of `[enabled, biasEnabled, bias, noiseReductionEnabled, threshold, amount, iterations]`; `toLuminance` / `toChrominance` select the target components. Setting a layer's first element false removes it.
- `PixelMath`: variables defined inside an expression (`name = ...;`) must be listed in `symbols`, otherwise the output is black. Defining the same sub-expressions in each of the three channel expressions multiplies the cost (a 24 MP, three-channel blend went from about 2 to about 10 minutes). `CIEL(rgbView)` yields lightness for a mask.
- `LocalHistogramEqualization`, `SCNR`, `CurvesTransformation` (properties `K`, `S`), `ChannelCombination` (`executeGlobal`, new window), `HistogramTransformation` (`H` rows: R, G, B, combined, alpha) accept parameters set from script.

## Data behaviours

- Stars-only images from StarXTerminator are almost entirely zero: a 24 MP linear stars layer had median 1e-8 and mean 1e-5. A midtones balance of 0.12 left them invisible; about 0.002-0.003 (the linear value mapped to 0.5) makes them visible.
- Stretching narrowband channels each to a common median (black point median - 2.7 sigma, then midtones) before combining is the approach used by the Seti Astro Perfect Palette Picker (source read in 1.3; CC BY-NC 4.0). It builds palettes with PixelMath on the stretched channels; the Foraxx SHO blend uses gates of the form `x ^ ~x`.
- Chroma noise dominates a hard-stretched OSC/DSLR result more than luminance noise; blurring only CIE a*/b* (or MMT on chrominance behind an inverted lightness mask) removes the colour mottling without softening detail.

## GUI automation of the PixInsight window (when no script route exists)

- Qt widgets expose a UI Automation tree (menu items, toolbars, docked process interfaces) but modal dialogs are not in the tree; screenshots plus keyboard navigation work. Invoking a menu item that opens a modal dialog blocks the UIA call until the dialog closes, so invoke it from a separate background process.
- On a 150 % scaled display a DPI-unaware script captures only the top-left 1280x720 of a 1920x1080 screen and misplaces `SetCursorPos` clicks; call `SetProcessDPIAware()` first.
- Per-user licence file `PixInsightLicense` copied to `%APPDATA%\Pleiades\` skips the activation dialog; the update check then lists RC-Astro packages.
