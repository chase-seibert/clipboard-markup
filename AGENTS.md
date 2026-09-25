# Repository Instructions

Also load the user-level instructions at `/Users/cseibert/.codex/AGENTS.md`.

## Repo Map

- `Package.swift`: SwiftPM package entrypoint for the macOS app.
- `Sources/ClipboardMarkup`: executable app entrypoint and delegate wiring.
- `Sources/ClipboardMarkupCore/Models`: codable domain models for clipboard history, shortcuts, and markup.
- `Sources/ClipboardMarkupCore/Stores`: app state and persistence coordination.
- `Sources/ClipboardMarkupCore/Services`: AppKit and platform services such as pasteboard, Quick Look, Preview, and shortcuts.
- `Sources/ClipboardMarkupCore/Views`: SwiftUI views for history, details, settings, menu bar, and image markup.
- `Sources/ClipboardMarkupCore/Support`: small helpers and extensions.
- `Resources`: app assets copied into the staged macOS bundle, including `AppIcon.icns`.
- `Tests/ClipboardMarkupCoreTests`: focused Swift tests.
- `docs`: local project documentation.
- `script/build_and_run.sh`: local build, app bundle staging, and launch script.

## Commands

Prefer Makefile targets for common workflows:

- `make setup`: resolve Swift package dependencies.
- `make analytics-config`: validate analytics environment variables and generate the ignored local plist.
- `make build`: build the app with SwiftPM.
- `make run`: build and launch the app bundle.
- `make verify`: build, launch, and confirm the app process is running.
- `make test`: run the test suite.
- `make clean`: clean SwiftPM and generated app bundle artifacts.

Signing defaults to the local team-backed Apple Development identity. Public
contributors without a team can use `SIGNING_MODE=unsigned make run` for a
local unsigned launch or `SIGNING_MODE=adhoc make run` for an ad-hoc test
signature. Team builds can override `DEVELOPMENT_TEAM` and
`CODE_SIGN_IDENTITY` without changing the repository.

Expose new recurring commands as Makefile targets before documenting ad hoc shell commands.

## Documentation

- `docs/initial-brainstorm.md`: original product request and early scope notes.
- `docs/product-requirements.md`: user stories and expected behavior.
- `docs/architecture.md`: data flow, persistence, services, and tradeoffs.
- `docs/design.md`: UI structure and interaction model.
- `docs/setup-install.md`: local setup, run, and validation steps.
