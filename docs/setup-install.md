# Setup And Install

## Requirements

- macOS 14 or newer.
- Xcode command line tools or a full Xcode installation with SwiftPM available.

## Local Workflow

```sh
make setup
make build
make run
```

`make run` builds the SwiftPM executable, stages `dist/ClipboardMarkup.app`, and launches the app bundle with normal foreground activation.

## Verification

```sh
make verify
make test
```

The app uses `Control` + `Option` + `C` as its default global shortcut. If another app owns that shortcut, the app still runs, and Settings shows that the shortcut is not registered until the conflict is removed or the shortcut is changed.

Use `Command` + `+` and `Command` + `-` to change app text size. Use `Command` + `0` to reset text size to 100%.

Open Settings to resize sidebar image thumbnails up to 160 pt. The sidebar can be dragged wider when using larger thumbnails. Image clip names start with the existing dimension-based fallback, then update from local text transcription when OCR finds readable text; editing the title in the detail header creates a manual name that takes precedence.

Use the search field at the top of the sidebar to filter the selected Library row by clip name, copied text content, or image OCR transcript. The Library filter defaults to Images; switch it to Text, All Clips, or Favorites to show other clipboard entries.
