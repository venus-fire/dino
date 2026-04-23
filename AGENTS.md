# Repository Guidelines

## Documentation First

Before changing code, read the docs that match your task. Start with `QWEN.md` for fork context, current version, maintenance notes, and conventions. Use `README.md` for feature overview and build basics, `FORK_STATUS.md` for upstream divergence, `ZOOM_FEATURE_DOCUMENTATION.md` for zoom work, and `READ_RECEIPTS_FEATURE.md` plus `READ_RECEIPTS_IMPLEMENTATION.md` for read receipt changes. `PUBLISHING.md` covers public fork messaging.

## Project Structure & Module Organization

Dino is a Vala/GTK XMPP client built with Meson. Core modules live in `libdino/src`, UI and entry points in `main/src`, XMPP protocol code in `xmpp-vala/src`, SQLite helpers in `qlite/src`, and optional features in `plugins/`. Tests are mainly in `xmpp-vala/tests` and `plugins/omemo/tests/native`. Packaging and distribution files live in `debian/`, `.github/workflows/`, and `im.dino.Dino.json`.

## Build, Test, and Development Commands

- `git status && git log -n 3 --oneline`: check local changes and recent context before editing.
- `meson setup build --prefix=$HOME/.local`: configure a local build directory.
- `meson compile -C build`: compile the application and plugins.
- `meson test -C build`: run the Meson test suite.
- `./build/main/dino`: launch the locally built app.
- `meson setup build -Dplugin-rtp=disabled`: example of disabling an optional plugin during configuration.

Install system dependencies first; `README.md` and `.github/workflows/build.yml` list Debian/Ubuntu packages.

## Coding Style & Naming Conventions

Follow surrounding Vala style: 4-space indentation, same-line braces, `snake_case` for methods and variables, `PascalCase` for classes, and module namespaces (`Dino`, `Xmpp`, `Dino.Ui`). Reuse existing settings, GTK construct block, signal, and plugin patterns. Meson options use lowercase hyphenated names, for example `plugin-http-files`.

## Testing Guidelines

Use GLib/Gee-style test cases as shown in `xmpp-vala/tests/jid.vala`, with names such as `jid_valid_full`. Add protocol tests under `xmpp-vala/tests` and OMEMO native tests under `plugins/omemo/tests/native` unless a closer test location exists. Run `meson test -C build`; use `--print-errorlogs` for failures. For UI changes, run `./build/main/dino` and manually verify the affected chat, zoom, or receipt workflow.

## Commit & Pull Request Guidelines

Recent history uses short imperative subjects, often prefixed with `Fix:` for bugs, for example `Fix: Read receipts not updating automatically...`. Keep commits focused and mention the affected feature. PRs should include a summary, linked issue when applicable, test results, and screenshots or recordings for UI changes.

## Agent-Specific Instructions

Do not overwrite user changes or generated build output. Prefer Meson and existing module patterns over ad hoc scripts. Keep changes scoped to the requested feature and update the relevant markdown when behavior, shortcuts, risks, or user-facing commands change.
