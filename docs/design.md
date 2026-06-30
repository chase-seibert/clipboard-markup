# Design

## Main Window

The app uses a two-pane macOS layout:

- Sidebar: Library filters, newest-first clip list, favorites subset.
- Detail pane: preview, metadata, and entry-specific actions.
- Menu bar extra: recent clips, Settings, and app open action.

The sidebar keeps native source-list styling. Rows use a text icon or configurable image thumbnail, a title, and a timestamp. Library rows combine the main filters: Images, Text, All Clips, and Favorites, with Images selected by default. Search filters the selected Library row across clip names, text contents, and image OCR transcripts. Richer controls stay in the detail pane.

Image entries start with the dimension-based fallback title, then use local text transcription as the automatic title when OCR completes. A manual rename in the detail header always overrides automatic naming.

## Text Detail

Text entries show the captured plain text preview and expose:

- Copy preferred text with `Command-C`.
- Copy as plain text with `Option-Command-C` when rich text is available.
- Favorite or unfavorite from the header star with `Command-D`.

## Image Detail

Image entries show the marked-up image by default when available. Controls expose:

- Copy the preferred image with `Command-C`.
- Markup with `Command-E`.
- Preview with `Shift-Command-O`.
- Quick Look with Space.
- View Original from the header.
- Favorite or unfavorite from the header star with `Command-D`.

## Markup Editor

The editor is optimized for simple screenshot annotation:

- Tool picker: arrow, rectangle, text, select.
- Color swatches.
- Line width slider.
- Text size slider.
- Font picker for text.

Arrows and rectangles are created by dragging. Text is created by typing the label and clicking the image. Selected objects can be moved; arrows and rectangles expose endpoint or corner handles for adjustment.

## Settings

Settings includes app text-size controls, thumbnail-size controls, a shortcut recorder for the global app shortcut, suggested presets, reset buttons, and registration status. The default global shortcut is `Control` + `Option` + `C`.

## Text Scaling

User-facing app text scales persistently with `Command` + `+`, `Command` + `-`, and `Command` + `0`. The Settings window exposes the same text-size setting as an Appearance control.

## Thumbnail Sizing

Image thumbnails default larger than the original compact row treatment and can be resized persistently from Settings up to 160 pt. The sidebar can be widened to make larger thumbnails easier to scan.
