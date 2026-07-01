# Design

## Main Window

The app uses a two-pane macOS layout:

- Sidebar: compact filter menu, newest-first clip list, favorites subset, deleted-items subset.
- Detail pane: preview, metadata, and entry-specific actions.
- Menu bar extra: recent clips, Settings, and app open action.

The sidebar keeps native source-list styling. Rows use a text icon or configurable image thumbnail, a title, and a timestamp. Image rows use hybrid thumbnails: the full image remains visible for context, with a centered 1:1 magnifying-glass lens over the middle of the screenshot when the thumbnail is below 50% of the original image scale. The lens position is consistent across thumbnails and uses a circular bordered treatment with a handle so it separates from the image behind it. Small thumbnails use a compact side-by-side row; image thumbnails at 120 pt or larger switch to a stacked row with metadata above the preview. A compact right-aligned icon-only filter menu combines Images, Text, All Clips, Favorites, and Deleted Items, with Images selected by default. Normal filters hide deleted clips; Deleted Items shows only soft-deleted clips and exposes restore actions. The active filter and selected clip persist across app restarts, falling back to the newest matching clip if the stored selection is no longer available. Search sits beside the filter as a magnifying-glass control that expands horizontally when clicked, filtering the selected view across clip names, text contents, and image OCR transcripts. Richer controls stay in the detail pane.

When a new clipboard item is captured, the app selects it and shows its detail view. If the active filter or search would hide the new item, the app switches to the matching item-kind filter and clears search so the new capture is visible.

Image entries start with the dimension-based fallback title, then use local text transcription as the automatic title when OCR completes. The detail header shows a compact pencil emoji button to focus the title field for manual renaming; a manual rename always overrides automatic naming.

## Text Detail

Text entries show the captured plain text preview and expose:

- Copy preferred text with `Command-C`.
- Copy as plain text with `Option-Command-C` when rich text is available.
- Favorite or unfavorite from the header star with `Command-D`.

## Image Detail

The selected entry can be deleted from the focused history list with Delete/Backspace, or from the trash icon in the detail header. Deleting an entry marks it with `deletedAt` and moves it to Deleted Items. Deleted entries keep their media files so they can be restored, and the app permanently purges deleted entries and their media after 30 days.

Image entries show the marked-up image by default when available. The preview sits on a subtle canvas with a stronger document-style border and shadow around the actual image so screenshots remain visually separate from the app chrome. Controls expose:

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

Settings is organized into tabs for Appearance, Shortcut, and LLM Integration. Appearance includes app text-size and thumbnail-size controls. Shortcut includes a recorder for the global app shortcut, suggested presets, reset buttons, and registration status. LLM Integration explains the local manifest/media layout, shows the data directory with an Open in Finder button, and provides a copyable prompt snippet that points agents at the generated `AGENTS.md`. The default global shortcut is `Control` + `Option` + `C`.

## Text Scaling

User-facing app text scales persistently with `Command` + `+`, `Command` + `-`, and `Command` + `0`. The Settings window exposes the same text-size setting as an Appearance control.

## Thumbnail Sizing

Image thumbnails default larger than the original compact row treatment and can be resized persistently from Settings up to 300 pt. The sidebar can be widened to make larger thumbnails easier to scan. Screenshot thumbnails keep the full image as context and overlay a centered 1:1 magnifying-glass lens only while the rendered thumbnail is below 50% scale.
