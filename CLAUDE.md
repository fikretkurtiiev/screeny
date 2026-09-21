# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **Status:** v1 feature set is implemented; overlay, hotkey and capture still need the manual checks listed under Testing.

## Project overview

**Screeny** is a personal, free, open-source screenshot tool modeled on Lightshot's workflow:

1. Press the global hotkey (default **⇧⌘S** / `Shift+Command+S`).
2. The screen freezes under a dimmed overlay.
3. Drag to select a region.
4. A toolbar appears next to the selection; draw on it (pen, line, arrow, rectangle, marker, text).
5. Copy to clipboard or save to disk. Esc cancels at any point.

The core promise is speed: hotkey to clipboard in a couple of seconds, zero friction, no accounts, no cloud.

### Goals (v1)
- Menu bar app (no Dock icon) with a global hotkey, default **⇧⌘S** (`Shift+Command+S`), changeable in Settings.
- Frozen-frame overlay across **all displays**, correct on Retina and mixed-DPI setups.
- Region selection with live size readout (W × H px), resize/move handles after selection.
- Annotation tools: pen (freehand), straight line, arrow, rectangle, marker/highlighter, text.
- Color picker (preset palette + custom) and stroke width.
- Undo / redo (⌘Z / ⇧⌘Z).
- Actions: copy (⌘C), save (⌘S), cancel (Esc).
- Settings: hotkey, default save folder, file name pattern, launch at login.

### Non-goals (for now)
- Cloud upload / share links (Lightshot's prntscr feature). If ever added, it must be opt-in and self-hostable.
- Video / GIF recording.
- Windows/Linux builds.
- Telemetry or analytics of any kind.

## Tech stack

- **Platform:** macOS 14+ (Sonoma) only.
- **Language:** Swift 5.10+ with strict concurrency checking enabled.
- **UI:** AppKit for the overlay, windows and menu bar; SwiftUI for the settings window and toolbar content where it fits. The overlay and canvas are AppKit (`NSView` + Core Graphics) because they need precise event handling and pixel-level rendering.
- **Capture:** ScreenCaptureKit (`SCScreenshotManager.captureImage`). Do not use `CGWindowListCreateImage` (deprecated).
- **Global hotkey:** [`KeyboardShortcuts`](https://github.com/sindresorhus/KeyboardShortcuts) (SwiftPM). Define it as `KeyboardShortcuts.Name("captureRegion", default: .init(.s, modifiers: [.command, .shift]))`. ⇧⌘S is "Save As…/Duplicate" in many apps, and a global registration takes it over system-wide. That's intended, but Settings must let the user rebind or clear it.
- **Launch at login:** `SMAppService.mainApp`.
- **Project generation:** [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml`. The `.xcodeproj` is **not** committed.
- **Dependencies:** Swift Package Manager only. Keep third-party dependencies to a minimum and justify each one.

## Commands

```bash
brew install xcodegen swiftlint swiftformat   # one-time setup
xcodegen generate                             # regenerate Screeny.xcodeproj
open Screeny.xcodeproj

# CLI build and test
xcodebuild -scheme Screeny -configuration Debug -destination 'platform=macOS' build
xcodebuild -scheme Screeny -destination 'platform=macOS' test

# single suite / test (tests use Swift Testing; note the trailing "()")
xcodebuild -scheme Screeny -destination 'platform=macOS' test -only-testing:ScreenyTests/AnnotationDocumentTests
xcodebuild -scheme Screeny -destination 'platform=macOS' test -only-testing:'ScreenyTests/AnnotationDocumentTests/undoRestoresPreviousSnapshot()'

swiftformat .                                 # format
swiftlint                                     # lint
```

After adding, removing or renaming source files, run `xcodegen generate`. Never edit the generated `.xcodeproj` by hand.

Ad-hoc signed builds get a new code signature on every rebuild, so macOS may forget the Screen Recording grant. If capture suddenly shows the permission alert, re-enable Screeny in System Settings or set a stable signing identity in `Config/Local.xcconfig` (included by `Config/Shared.xcconfig`).

Unit tests run hosted in the app; `AppDelegate` skips the status item and hotkey when `XCTestConfigurationFilePath` is set.

## Architecture

```
Screeny/
├── App/
│   ├── ScreenyApp.swift          # @main entry (plain AppKit, no SwiftUI scenes), LSUIElement menu bar app
│   ├── AppDelegate.swift          # status item, hotkey registration, lifecycle
│   └── AppCoordinator.swift       # owns the capture session state machine
├── Capture/
│   ├── ScreenCapturer.swift       # ScreenCaptureKit wrapper, one frozen image per display
│   └── PermissionManager.swift    # Screen Recording permission check and prompt
├── Overlay/
│   ├── OverlayWindow.swift        # borderless NSPanel per display
│   ├── OverlayView.swift          # frozen frame, dim, chrome, canvas, mouse/keys, text field; one per display
│   ├── SelectionController.swift  # drag/resize/move logic (pure, pixel-grid snapped)
│   └── SelectionSpace.swift       # the single view-points ↔ selection-pixels conversion
├── Annotation/
│   ├── Annotation.swift           # enum Annotation (value types) + Tool enum
│   ├── AnnotationDocument.swift   # [Annotation] + undo/redo stacks
│   ├── Renderer.swift             # draws annotations into a CGContext
│   └── Tools/                     # one file per tool's input handling
├── Toolbar/
│   ├── ToolbarView.swift          # SwiftUI; inline controls only (menus/popovers open under the overlay)
│   ├── ToolbarModel.swift         # @Observable state + callbacks into OverlayView
│   ├── ToolbarLayout.swift        # placement next to the selection
│   └── ColorPanelBridge.swift     # NSColorPanel raised above .screenSaver level
├── Export/
│   ├── Exporter.swift             # flatten image + annotations → PNG
│   ├── ClipboardExporter.swift    # PNG + TIFF on the pasteboard
│   ├── FileExporter.swift         # save panel, default folder
│   └── FileNamePattern.swift      # "{…}" = DateFormatter format
├── Settings/
│   ├── Preferences.swift          # UserDefaults-backed settings
│   └── SettingsView.swift
└── Resources/
    └── Assets.xcassets
ScreenyTests/
project.yml
```

### Capture session flow

`AppCoordinator` drives a small state machine:

```
idle → capturing → selecting → annotating → (exporting) → idle
```

Any state can go to `idle` on Esc. Only one session may be active at a time; a hotkey press during an active session is ignored.

`OverlayView` owns the per-display interaction (selection, tools, `AnnotationDocument`) and reports to `AppCoordinator` through `OverlayViewDelegate`. The coordinator clears other displays' selections, performs copy/save, and on session end re-activates the previously frontmost app, because an accessory app doesn't hand focus back by itself. Save dismisses the overlay *before* showing `NSSavePanel`, since nothing can appear above a `.screenSaver`-level window.

### Key design rules

- **Freeze first, then show UI.** Capture every display's image *before* the overlay windows appear, so the overlay never ends up in the screenshot and the user draws on a static frame.
- **One overlay window per `NSScreen`.** Windows are borderless `NSPanel`s at `.screenSaver` level, `canJoinAllSpaces` + `fullScreenAuxiliary`, and must accept key events (Esc, ⌘C, ⌘S, ⌘Z). Selection is limited to a single display in v1.
- **Coordinates:** keep all annotation geometry in **selection-local pixel coordinates** (not points). Convert from view points using the screen's `backingScaleFactor` at the input boundary only (`SelectionSpace`). The bottom-left/top-left flip happens in exactly one place: `OverlayView.isFlipped == true`. `Renderer` always draws into a y-down context; the exporter flips its bitmap context to match. The selection rect is snapped to the pixel grid, and when it moves, annotations are translated so they stay pinned to the image.
- **Annotations are data.** `Annotation` is an `enum` of `Sendable`, `Equatable` value types (e.g. `.stroke(points:color:width:)`, `.arrow(from:to:…)`, `.text(string:origin:fontSize:color:)`). Views never draw ad hoc; the on-screen canvas and the exporter both use the same `Renderer`, so what you see is exactly what you export.
- **Undo** is a snapshot/stack of the annotation array in `AnnotationDocument`, not `NSUndoManager` magic spread across views.
- **Export** crops the frozen image to the selection at full native resolution, draws annotations on top, and writes PNG. Clipboard puts PNG data on `NSPasteboard.general`.
- **Permissions:** on first capture, check `CGPreflightScreenCaptureAccess()`. If access is missing, show a clear explanation and a button that opens the Screen Recording pane in System Settings. Never fail silently.

## Coding conventions

- Swift API Design Guidelines. Prefer `struct`/`enum`, use `final class` only where identity or AppKit requires it.
- `@MainActor` on everything that touches UI. Capture runs async and hops back to the main actor to present overlays.
- No force unwraps outside tests and `IBOutlet`-style guarantees; use `guard` with meaningful handling.
- Small files, one primary type per file. Folder = feature.
- Keep the overlay responsive: no allocations in `draw(_:)` hot paths beyond what's necessary. The dim is a fill over the frozen image (no second full-screen bitmap), and selection changes invalidate only the old and new chrome rects.
- Use `Logger` (os.log) with a subsystem per feature, not `print`. Loggers live in `App/Log.swift` (`Logger.capture`, `.overlay`, `.export`, …).
- Comments explain *why*, not *what*.

## Testing

- Unit test the pure parts: geometry and coordinate conversion, `AnnotationDocument` undo/redo, file name pattern formatting, and `Renderer` output (render into an offscreen context, compare pixels or hashes against fixtures).
- Overlay, hotkey and capture are verified manually. Before merging UI changes, check:
  - single display, Retina
  - two displays with different scale factors
  - a full-screen app on another Space
  - dark and light mode

## Git & GitHub

- `main` is always buildable. Work on short-lived branches, conventional commits (`feat:`, `fix:`, `refactor:`, `chore:`).
- `.gitignore` must cover `*.xcodeproj`, `DerivedData/`, `.build/`, `xcuserdata/`, `.DS_Store`.
- License: MIT.
- Code signing: ad-hoc / "Sign to Run Locally" for personal use. Do not commit signing identities or team IDs; keep them in an uncommitted `Local.xcconfig`.

## Roadmap (after v1)

- Blur/pixelate tool for redacting sensitive data.
- Numbered step markers.
- Capture a window under the cursor on click.
- Pin a screenshot as a floating window.
- Optional self-hosted upload target.

## Working with Claude

- Before large changes, propose a short plan and wait for confirmation.
- When a macOS API has version-specific behavior, target macOS 14+ and note it in a comment.
- Don't add dependencies without asking.
- Update this file when architecture or conventions change.
