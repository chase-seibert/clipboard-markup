# Initial Brainstorm

## Original Request

Create a new macOS app that saves clipboard contents. Each time something is copied to the clipboard, it should show up in the app. Start with text, rich text, images, and screenshots. The app should not trigger screenshot capture; built-in macOS screenshot utilities still write to the clipboard, and this app should record what appears there.

The regular macOS paste shortcuts should continue to work. The app should show a newest-first history, support copying previous entries back to the clipboard, and allow image entries to be marked up locally. Image markup should be simple: large arrows, resizable rectangles, and text in configurable colors, sizes, fonts, and line widths. A marked-up image entry should retain both the original image and the marked-up version. Selecting an image entry should prefer copying the marked-up image when one exists, while still allowing access to the original.

Images should open in Preview and support Quick Look. Clipboard contents should be saved locally in a shape that can eventually replicate through iCloud to a mobile device. Some entries should be saveable to a separate saved-items list for long-term retrieval. A global keyboard shortcut should launch or foreground the app. Text entries should support copying as plain text or rich text.

## First Implementation Scope

- Native SwiftUI macOS app.
- NSPasteboard polling by change count.
- Local Application Support manifest plus media directory.
- Newest-first history and favorites subset.
- RTF, plain text, and image capture.
- Copy actions that suppress self-created duplicate captures.
- Basic native image markup editor with arrows, rectangles, and text.
