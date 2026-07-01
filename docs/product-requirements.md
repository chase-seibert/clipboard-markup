# Product Requirements

## User Stories

- As a macOS user, I want every copied text, rich text, image, or screenshot to appear in a history list so that I can retrieve previous clipboard items.
- As a macOS user, I want normal copy and paste shortcuts to keep working so that the app does not disrupt system clipboard behavior.
- As a macOS user, I want previous entries ordered newest first so that recent items are easy to find.
- As a macOS user, I want to copy any previous entry back to the clipboard so that I can paste it into another app.
- As a macOS user, I want text entries to support plain-text and rich-text copy modes so that I can choose whether formatting is preserved.
- As a macOS user, I want image entries to preserve the original and the marked-up image so that I can recover the clean source later.
- As a macOS user, I want simple arrow, rectangle, and text markup tools so that screenshots can be annotated quickly without Preview markup friction.
- As a macOS user, I want to open images in Preview and Quick Look so that I can inspect them using standard macOS tools.
- As a macOS user, I want favorites as a curated subset of history so that important clips remain easy to retrieve.
- As a macOS user, I want a global keyboard shortcut to show the app so that returning to an old clipboard item is fast.
- As a macOS user, I want to configure the global shortcut in Settings so that it does not conflict with my other utilities.
- As a macOS user, I want a menu bar icon with recent clips so that I can quickly restore common clipboard items without opening the full window.
- As a macOS user, I want to scale the app's text size with keyboard shortcuts and Settings so that the UI stays comfortable to read.
- As a macOS user, I want to resize image thumbnails in the history list so that screenshots are easier to recognize.
- As a macOS user, I want text clips to show a readable preview tile in the history list so that copied snippets are recognizable without opening the detail view.
- As a macOS user, I want screenshot thumbnails to show readable text without losing visual context so that similar screenshots are easier to distinguish.
- As a macOS user, I want image entries to get useful names from visible text in the image while still letting me rename them myself.
- As a macOS user, I want to search clip names, copied text, and image OCR text so that older clips are quick to find.
- As a macOS user, I want the history list to default to images while letting me switch to text, all clips, favorites, or deleted items so that screenshot work stays uncluttered.
- As a macOS user, I want to delete selected clipboard entries into a recoverable Deleted Items view so that I can clean up unwanted history without losing something immediately.
- As a macOS user, I want deleted entries to be permanently removed after 30 days so that old unwanted media is eventually cleaned up.
- As a macOS user, I want to clear all captured clipboard history and media from Settings with confirmation so that I can reset the app without changing preferences or the current system clipboard.
- As a macOS user, I want the local data directory to include guidance for LLM coding agents so that I can ask agents to inspect clipboard history and associated media.
- As a macOS user, I want Settings to show the data directory, open it in Finder, and copy a short prompt pointing agents at the generated `AGENTS.md` so that I can easily provide clipboard history context.

## Non-Goals For The First Version

- iCloud synchronization.
- Mobile companion app.
- Browser extension capture.
- Shape recognition or complex image editing.
- Clipboard capture for arbitrary file types beyond image file URLs.
