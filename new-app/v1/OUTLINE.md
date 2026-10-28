# v1 — Stack & Scope Decisions

> **Companion to:** `../OUTLINE.md` (north-star feature outline — *what the app does*). This file records *how we build v1*: locked technical decisions and v1 scope boundaries.
> **Status:** locked 2026-10-27 unless marked open. Feature scope for v1 comes from the user's v1 outline (pending, next discussion).

## Scope statement

**v1 = a simple, working Linux desktop app.** Linux first; Android only after v1 is stable. Explicit non-goals for v1: sync, webapp, widgets, import/export. App identity (name, package ID) deferred until Android work begins.

## Decisions

- **D1 — Stack: Flutter + Dart.** One language compiling to all target frontends (Linux desktop now; Android later). Chosen over Rust+Tauri (two ecosystems, webview quirks, more moving parts for a non-coder-maintained project) and Kotlin Multiplatform (transparent windows broken on Linux — hard requirement failed).

- **D2 — Architecture: three layers, one monorepo.**
  ```
  new-app/
    packages/engine/   pure Dart: data model, state machine, projection math, persistence
    apps/desktop/      Flutter Linux app: UI + Linux adapters
    apps/android/      (later) Flutter Android app + alarm adapters
  ```
  Engine has **no Flutter imports and no direct OS access** — clock, storage, notifications are injected interfaces ("dependency injection"). This makes the engine testable with simulated/virtual time and keeps it frontend-agnostic.

- **D3 — Engine testing is heavy; UI testing is light.** The wall/cut/skip/projection logic is the heart of the app; it gets hundreds of fast unit tests running against a virtual clock. UI gets smoke-level coverage only.

- **D4 — Storage: SQLite via the `drift` package**, in the standard XDG data directory. Every object carries a permanent UUID; an **append-only change log** is written alongside the DB from day one (cheap insurance for future sync — not a v1 feature).

- **D5 — Background behavior: no daemon.** The app fires alarms while running; closing goes to the **system tray**. (Android later gets proper AlarmManager/foreground-service treatment per the MultiTimer SPEC.)

- **D6 — Transparency is de-risked first.** A throwaway transparent-window prototype runs on the user's desktop in week one (GTK alpha recipe in the Linux runner) before any real UI is built. Blur comes from the user's compositor; the app's only job is an alpha background.

- **D7 — Aesthetic requirement:** app conforms to the user's OS theme of transparent windows with compositor blur.

- **D8 — Icons: Material Symbols (bundled with Flutter).** Nothing to acquire; 2,000+ icons, swappable later. Interval labels in v1 are text + color; per-interval icon sets (MultiTimer-style) deferred.

- **D9 — Fonts: bundle the user's own fonts as local-only assets.** UI text = **ProLisa** (user's GTK theme font); timer/number readouts = **MonoLisa Medium** (monospace → digits don't jitter while counting). Flutter doesn't inherit system fonts, so TTFs ship as app assets; font files stay **gitignored** (public repo, licensed fonts — local-only, like `REFERENCE/`). *(Pending user confirmation.)*

## Process

- Development is agent-written; docs and decisions live in this repo (`new-app/`), north star in `../OUTLINE.md`, MultiTimer reference SPEC in `../../multitimer-spec/SPEC/`.
- Engine design should consult the MultiTimer SPEC for timer-engine subtleties (wall-clock anchoring, zero-crossing, boot re-arm) — describe, don't port.
