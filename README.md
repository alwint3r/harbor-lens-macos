# Harbor Lens

A native macOS trajectory reader for Harbor trial `trajectory.json` files. Harbor Lens renders ATIF prompts and agent responses as Markdown, keeps reasoning visible, pairs tool calls with their results, and aligns two runs by step ID for comparison.

## Requirements

- macOS 14 or later
- Xcode 15 or later

No third-party dependencies are required.

## Run

1. Open `HarborTrajectoryViewer.xcodeproj` in Xcode.
2. Select the **HarborTrajectoryViewer** scheme.
3. Build and run with **⌘R**.
4. Open a `trajectory.json`, then choose **Add comparison** (or press **⇧⌘O**) to load a second run.

You can also drag one or two JSON files into the window. Tool results are collapsed by default; select **Show** on a result to inspect it.

Two small ATIF fixtures are available in [`Samples/`](Samples/) for trying single-run and comparison modes.

## Command-line build and install

[`scripts/build.sh`](scripts/build.sh) wraps `xcodebuild` and leaves the app in
`.build/Build/Products/`:

```sh
scripts/build.sh            # Release build
scripts/build.sh --debug    # Debug build
scripts/build.sh --tests    # build and run the unit tests
scripts/build.sh --clean    # clean, then build
```

[`scripts/install.sh`](scripts/install.sh) refreshes the build and copies the app
into `/Applications`:

```sh
scripts/install.sh                    # build Release, install to /Applications
scripts/install.sh --user             # install to ~/Applications instead
scripts/install.sh --no-build --open  # install the existing build and launch it
```

Run either script with `--help` for all options.

## App icon

[`scripts/make-icon.swift`](scripts/make-icon.swift) draws the app icon — a magnifier
held over a stepped trajectory, with the inspected step in the comparison color —
and writes every size into
[`Assets.xcassets/AppIcon.appiconset`](HarborTrajectoryViewer/Assets.xcassets/AppIcon.appiconset):

```sh
swift scripts/make-icon.swift            # regenerate the icon assets
swift scripts/make-icon.swift --preview  # also render .build/icon-preview.png
```

The design constants at the top of the script (lens geometry, route steps, palette)
control the artwork; the preview sheet shows the 16–256 px renders next to the
master for a legibility check.
