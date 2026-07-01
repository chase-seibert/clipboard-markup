# Changelog

## 2026-06-30

- Created the SwiftPM macOS app scaffold.
- Added clipboard history persistence for text, rich text, and images.
- Added saved items, copy actions, Preview/Quick Look hooks, global shortcut support, and image markup tools.
- Added Favorites wording, a Settings shortcut recorder, menu bar recent clips, image thumbnails, and visible action shortcuts.
- Added the generated stacked-clipboard markup image as the macOS app icon.
- Polished the main window spacing, sidebar row density, detail header hierarchy, action button sizing, image preview framing, and single-window tab behavior.
- Added persistent app font scaling through Settings and Command-plus, Command-minus, and Command-zero shortcuts.
- Added configurable image thumbnail sizing, renameable clip titles, and local image text transcription for automatic image names.
- Added stacked text snippet preview tiles in the clipboard history list.
- Skipped password-manager and other sensitive pasteboard contents when macOS marker/source types identify them.
- Added a detail title pencil emoji button for manual renaming.
- Added sidebar search across clip names, copied text contents, and image OCR transcripts.
- Added `Command-F` to open and focus the sidebar search field.
- Replaced the tall Library filter rows with a compact right-aligned sidebar filter menu, still defaulting the list to Images.
- Moved search back beside the sidebar filter as a magnifying-glass control that expands horizontally when clicked.
- Increased the maximum sidebar thumbnail size to 300 pt and widened the resizable sidebar range.
- Simplified detail actions by shortening Copy and Preview labels, moving Favorite into the header, and replacing Copy Original with a View Original header link.
- Added hybrid screenshot thumbnails with full-image context and a centered 1:1 magnifying-glass lens.
- Enlarged the screenshot thumbnail magnifying lens and hid it when thumbnails are already at least 50% scale.
- Added an adaptive stacked sidebar row for large image thumbnails and a stronger document-style border around the image detail preview.
- Persisted the selected sidebar filter and selected clipboard item across app restarts.
- Added entry deletion from the focused history list with Delete/Backspace and a trash icon in the detail header.
- Changed deletion to a recoverable Deleted Items flow with restore actions and 30-day permanent purging.
- Added a generated data-directory `AGENTS.md` guide and a Settings LLM Integration tab with Finder access and a copyable agent prompt snippet.
- Renamed the Settings integration area to Data and added a confirmed clear-history action for captured clipboard data and media.
- Automatically selected and navigated to newly captured clipboard items.
- Polished the sidebar, detail header/action bar, preview surface, and Settings controls with more consistent spacing, icon treatment, and blue primary actions.
- Simplified the markup editor toolbar with compact monochrome tools, a color menu, clean width/size controls, and direct on-canvas text editing.
- Added top-bar markup editor actions for reverting all markup and deleting the selected markup, plus clearer color and line-weight dropdowns.
- Grouped markup editor controls into tool, shape, text, and color sections and persisted markup color, line weight, and text size preferences.
