# Architecture

## App Shape

Clipboard Markup is a SwiftPM-packaged SwiftUI macOS app. The main scene is a `WindowGroup` with a `NavigationSplitView`: a native sidebar for history and favorites, and a detail surface for copy actions, Preview/Quick Look, and markup. A `Settings` scene owns preferences, and a `MenuBarExtra` exposes recent clips.

## Data Flow

1. `PasteboardMonitor` polls `NSPasteboard.general.changeCount`.
2. `PasteboardReader` converts pasteboard contents into a `ClipboardCapture`.
3. `ClipboardStore` deduplicates against the newest item, writes media assets through `ClipboardStorage`, and publishes a newest-first `items` array.
4. Image clips without a transcript are sent to local Vision OCR; the result is persisted as automatic naming metadata.
5. Views call store methods to copy entries, rename entries, toggle favorite state, or update image markup.
6. Copy actions update the pasteboard and advance the monitor checkpoint so the app does not re-capture its own writes.

## Persistence

Local data lives in:

`~/Library/Application Support/ClipboardMarkup`

The storage layout is:

- `entries.json`: codable manifest of clipboard entries and markup model data.
- `Media`: PNG image assets and RTF payloads.

This keeps metadata and binary assets relocatable. A future iCloud implementation can move the same manifest/media shape into an iCloud container or CloudKit-backed location.

## Platform Bridges

- `NSPasteboard` for clipboard reading and writing.
- Carbon `RegisterEventHotKey` for the configurable global shortcut.
- `NSWorkspace` for opening image files in Preview.
- `QLPreviewPanel` for Quick Look.
- Vision text recognition for local image transcription.
- AppKit drawing in `MarkupRenderer` to flatten image annotations into PNG assets.

## Tradeoffs

The pasteboard is polled instead of intercepted. macOS does not provide a public general clipboard event stream, and polling `changeCount` is the common lightweight pattern for clipboard managers. The first version stores only text, RTF, and images to keep the data model compact.
