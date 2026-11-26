# NINA 3.2 sequence files (generating and checking them)

Facts observed against NINA 3.2.0.9001. Verify against the installed NINA before relying on them for a different version.

## Building a sequence file without hand-writing JSON

- Construct the tree with NINA's own sequencer classes (from `NINA.Sequencer.dll` in the install folder) and serialise with NINA's `SequenceJsonConverter`. Reading the file back through the same converter and re-saving gives a byte-identical file; this is the strongest check available without starting NINA.
- A full sequence (Start / Targets / End areas) loads through the sequencer's Load button. It is not a template for the template folder.
- Instruction types seen in 3.2: `Utility.MessageBox` (pauses until Continue is pressed; the pause itself was not tested), `Utility.Annotation`, `Focuser.MoveFocuserRelative` (property `RelativePosition`; whether the unit is focuser steps was not tested), `Platesolving.Center`, `Autofocus.RunAutofocus`, `Imaging.TakeManyExposures`.
- `TakeManyExposures` is a container: one child `TakeExposure` (`ExposureTime`, `Gain`, `Offset`, `ImageType`, `Binning`) plus a `LoopCondition` whose `Iterations` is the frame count. Gain `-1` means the camera default.
- Binning is a `BinningMode` object (`X`, `Y`). After copy/paste in the UI, later instructions can hold a `{"$ref": "<id>"}` to an earlier binning object instead of their own copy.
- A `DeepSkyObjectContainer` carries `Name` and `Target.TargetName`; the UI keeps them equal. Its `Target.InputCoordinates` is RA/Dec split into hours/minutes/seconds and sign/degrees/minutes/seconds. Coordinates only matter for instructions inside that container that use them (e.g. Center); the container does not slew by itself.

## Image file pattern tokens

`$$TARGETNAME$$` (the target name of the enclosing container), `$$STARCOUNT$$` and `$$HFR$$` (HFR only when HFR detection is on in NINA's options) are listed in the NINA token list; tokens are case-sensitive. NINA shows a live preview of the resulting file name in the imaging options. Sources: <https://gist.github.com/TaylorBurnham/e1c66000b2ccf335eba89d40a4d82203>, <https://app.astrobin.com/forum/topic/128077/fit-filename-in-nina>.

## UI automation

The content of NINA's tab pages is not exposed to Windows UI Automation (the raw tree shows only the tab headers), so docked plugin panels cannot be driven or read by UIA. Workaround that worked: open a pop-out window of the same view model from the plugin when an environment variable is set, and drive that. The docked rendering can then only be checked by screenshot.
