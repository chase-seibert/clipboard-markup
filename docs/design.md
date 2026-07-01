# Design

## Main Window

The app uses a two-pane macOS layout:

- Sidebar: compact filter menu, newest-first clip list, favorites subset, deleted-items subset.
- Detail pane: preview, metadata, and entry-specific actions.
- Menu bar extra: compact visual popover with Recent and Favorites clip sections, Settings, Quit, and app open action. Recent image clips show larger color thumbnails; text clips show snippet previews. Rows copy on click and expose compact Markup and Favorite actions where applicable.

The sidebar keeps native source-list styling. Rows use configurable previews, a title, and a timestamp. Text rows always use a stacked layout with metadata above a bordered snippet tile that fills the configured preview height and truncates overflowing content. Image rows use hybrid thumbnails: the full image remains visible for context, with a centered 1:1 magnifying-glass lens over the middle of the screenshot when the thumbnail is below 50% of the original image scale. The lens position is consistent across thumbnails and uses a circular bordered treatment with a handle so it separates from the image behind it. Small image thumbnails use a compact side-by-side row; image thumbnails at 120 pt or larger switch to a stacked row with metadata above the preview. A compact right-aligned icon-only filter menu combines Images, Text, All Clips, Favorites, and Deleted Items, with Images selected by default. Normal filters hide deleted clips; Deleted Items shows only soft-deleted clips and exposes restore actions. The active filter and selected clip persist across app restarts, falling back to the newest matching clip if the stored selection is no longer available. Search sits beside the filter as a magnifying-glass control that expands horizontally when clicked or when `Command-F` is pressed, filtering the selected view across clip names, text contents, and image OCR transcripts. Richer controls stay in the detail pane.

When a new clipboard item is captured, the app selects it and shows its detail view. If the active filter or search would hide the new item, the app switches to the matching item-kind filter and clears search so the new capture is visible.

Image entries start with the dimension-based fallback title, then use local text transcription as the automatic title when OCR completes. The detail header shows a compact pencil emoji button to focus the title field for manual renaming; a manual rename always overrides automatic naming.

## Mac Commands

The app exposes native menu commands for selected clip actions. `Clip` menu items validate against the focused selection, with disabled states for no selection, deleted clips, and type-specific actions. `File > Export Selected Clip...` exports text as `.txt`, rich text as `.rtf`, and images as `.png`; image exports can use either the preferred marked-up image or the original source. The same selected clip payloads are available for drag and Share where macOS supports them.

Rename, favorite, delete, restore, and saved markup updates participate in Undo/Redo. The markup editor also supports local undo before save for adding, moving, resizing, deleting, reverting, and restyling markup elements. Clear Clipboard History remains permanent and is not undoable.

## Text Detail

Text entries show the captured plain text preview and expose:

- Copy preferred text with `Command-C`.
- Copy as plain text with `Option-Command-C` when rich text is available.
- Favorite or unfavorite from the header star with `Command-D`.

## Image Detail

The selected entry can be renamed from the focused history list with Command-Return and deleted with Delete/Backspace, or from the trash icon in the detail header. The `Clip` menu labels focused-list shortcuts for Rename and Delete. Deleting an entry marks it with `deletedAt` and moves it to Deleted Items. Deleted entries keep their media files so they can be restored, and the app permanently purges deleted entries and their media after 30 days.

Image entries show the marked-up image by default when available. The preview expands with the detail pane height so taller windows show larger screenshots, while the rendered image stops at native 1:1 size instead of upscaling. The preview sits on a subtle canvas with a stronger document-style border and shadow around the actual image so screenshots remain visually separate from the app chrome. Controls expose:

- Copy the preferred image with `Command-C`.
- Markup with `Command-E`.
- Quick Look with Space.
- View Original from the header.
- Favorite or unfavorite from the header star with `Command-D`.

## Markup Editor

The editor is optimized for simple screenshot annotation:

- Tool picker: select, arrow, rectangle, and text.
- Line weight dropdown for arrow and rectangle strokes.
- Text size stepper for selected text elements.
- Color dropdown with named swatches.
- Revert Markup and Delete Selected Markup actions.

Arrows and rectangles are created by dragging. Text is created by selecting the text tool, clicking the image, and typing directly on the image. Selected objects can be moved; arrows and rectangles expose endpoint or corner handles for adjustment. Pressing Return in an active text markup commits that text field, and `Command-Return` inserts a new line.

## Window, Help, And Accessibility

The main window uses a standard autosave frame name and remains a single-window app. The Help menu opens bundled local help covering shortcuts, filters, markup, storage, and privacy. Sidebar search and filter animations respect Reduce Motion. Icon-only controls in the sidebar, detail header, thumbnail lens, detail actions, and markup toolbar include accessibility labels or hints.

## Settings

Settings is organized into tabs for Appearance, Shortcut, Storage Location, and Other. Appearance includes app theme, text-size, and thumbnail-size controls. The theme setting can follow the system appearance or force Light or Dark mode. Shortcut includes a recorder for the global app shortcut, suggested presets, reset buttons, and registration status. Storage Location explains the local manifest/media layout, offers storage-location presets for the default local folder, iCloud Drive, Dropbox, and Google Drive plus a custom folder picker, and gives every location row an Open in Finder action. Other provides a copyable prompt snippet that points agents at the generated `AGENTS.md` and includes a confirmed destructive control for clearing captured clipboard history and media. The default global shortcut is `Control` + `Option` + `C`.

## Text Scaling

User-facing app text scales persistently with `Command` + `+`, `Command` + `-`, and `Command` + `0`. The Settings window exposes the same text-size setting as an Appearance control.

## Thumbnail Sizing

Image thumbnails default larger than the original compact row treatment and can be resized persistently from Settings up to 300 pt. The sidebar can be widened to make larger thumbnails easier to scan. Screenshot thumbnails keep the full image as context and overlay a centered 1:1 magnifying-glass lens only while the rendered thumbnail is below 50% scale.
