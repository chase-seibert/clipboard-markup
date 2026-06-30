# Clipboard Markup

Clipboard Markup is a native macOS clipboard history app focused on text, rich text, images, screenshots, and quick image annotation.

The app polls the macOS pasteboard, records new clipboard contents locally, and keeps the regular system clipboard behavior intact. Text entries can be copied back as plain text or rich text. Image entries keep both the original image and an optional marked-up image, with actions to copy the preferred image, view the original, open in Preview, or Quick Look the file.

## Current Scope

- Clipboard history ordered newest first.
- Sidebar search across clip names, text contents, and image OCR transcripts.
- Sidebar Library filters for Images, Text, All Clips, and Favorites, defaulting to Images.
- Favorites as a bookmarked subset of the full history.
- Text and RTF capture, with plain-text and rich-text copy actions.
- Image and screenshot capture from the system pasteboard.
- Larger, resizable sidebar thumbnails for image clips.
- Renameable clipboard entries, with image names updated from local OCR when text is found.
- Simple image markup: arrows, rectangles, and text with color and size controls.
- Configurable global shortcut, defaulting to `Control` + `Option` + `C`.
- Menu bar icon with recent clipboard items and quick access to the app.
- User-facing text scaling with `Command` + `+`, `Command` + `-`, and `Command` + `0`.
- Local persistence under Application Support using a manifest plus media files.

## Commands

```sh
make setup
make build
make run
make verify
make test
```

See `docs/setup-install.md` for more detail.
