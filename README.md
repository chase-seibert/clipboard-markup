# Clipboard Markup

Clipboard Markup is a native macOS clipboard history app focused on text, rich text, images, screenshots, and quick image annotation.

The app polls the macOS pasteboard, records new clipboard contents locally, and keeps the regular system clipboard behavior intact. Text entries can be copied back as plain text or rich text. Image entries keep both the original image and an optional marked-up image, with actions to copy the preferred image, view the original, open in Preview, or Quick Look the file.

## Current Scope

- Clipboard history ordered newest first.
- New clipboard captures are selected automatically.
- Compact icon-only sidebar filter menu for Images, Text, All Clips, Favorites, and Deleted Items, defaulting to Images.
- Expanding sidebar search across clip names, text contents, and image OCR transcripts, opened with `Command-F`.
- Persisted sidebar filter and selected clip across app restarts.
- Delete selected entries into Deleted Items, restore them from there, and permanently purge them after 30 days.
- Clear all captured clipboard history and media from Settings without changing app preferences or the system clipboard.
- Favorites as a bookmarked subset of the full history.
- Text and RTF capture, with stacked snippet preview tiles plus plain-text and rich-text copy actions.
- Image and screenshot capture from the system pasteboard.
- Hybrid sidebar thumbnails for image clips, with full-image context plus a centered 1:1 magnifying-glass lens when thumbnails are below 50% scale, and stacked rows at larger thumbnail sizes.
- Renameable clipboard entries, with image names updated from local OCR when text is found.
- Simple image markup: arrows, rectangles, and text with color and size controls.
- Configurable global shortcut, defaulting to `Control` + `Option` + `C`.
- Menu bar icon with recent clipboard items and quick access to the app.
- User-facing text scaling with `Command` + `+`, `Command` + `-`, and `Command` + `0`.
- Local persistence under Application Support using a manifest plus media files, with a generated `AGENTS.md`, Finder access, a Settings prompt snippet for LLM-assisted inspection, and a Settings data reset.

## Commands

```sh
make setup
make build
make run
make verify
make test
```

See `docs/setup-install.md` for more detail.
