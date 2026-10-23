# MultiTimer Rebuild SPEC — Android (`com.persapps.multitimer` v1.14.1 (282))

Phase 1 deliverable. This directory describes the MultiTimer Android app completely enough to rebuild it without the original. It is a synthesis: every load-bearing claim is backed by one of the FINDINGS documents, which in turn carry file:line citations into the decompiled APK.

## What was analyzed

- Target: **`com.persapps.multitimer` versionName 1.14.1, versionCode 282** (version pin accepted 2026-10-22). Base APK sha256 `4cff45f47fb1384003fb7e3c5d46564d0a2f87cc77db92eb99bbab5b2ae8e236` — full identity, tooling, and currency check in `WORK/APK-INFO.md`.
- Method: static analysis (jadx 1.5.6 + apktool 3.0.3) of the decompiled tree (7,295 Java files; heavy R8 obfuscation — 6,460 merged classes, 78 readable shell classes), cross-checked against 61 fetched help-center pages (`REFERENCE/`) and 23 user-provided iOS screenshots (`REFERENCE-IMAGES/index.md`). No dynamic analysis was performed.
- The app is **local-only**: no app-feature networking exists (Part 7 exclusions; Part 5 §6.0). Everything below runs offline.

## Files

| File | Contents |
| --- | --- |
| `features.md` | Complete feature inventory by area, each with status (documented / partial / gap) and inline `**(PRO)**` marks |
| `data-model.md` | Entities, relationships, persistence, preferences, interchange formats (condensed) |
| `engine.md` | **The core document**: timer types, state machine, zero-crossing, linking/sequencing, background operation, alert delivery |
| `ui.md` | Screen map, navigation, per-screen structure, widgets, theming |
| `gaps.md` | Everything unresolvable from this build, with evidence and confidence |

## Deep references (FINDINGS, cited throughout)

`FINDINGS/data-model.md` (Part 3), `FINDINGS/engine.md` (Part 4), `FINDINGS/background-and-alerts.md` (Part 5), `FINDINGS/ui-structure.md` (Part 6), `FINDINGS/settings-sounds-pro.md` (Part 7), `FINDINGS/exclusions.md` (Part 7). Raw citations look like `defpackage/ka2.java:468-505` = file+lines in the jadx tree at `WORK/decompiled/jadx/sources/`. Obfuscated identifiers (e.g. `ka2`, `g5vs`) are quoted verbatim from the binary; readable names (e.g. `MainActivity`, `bj1l` store keys, XML tags) survive in the binary itself.

## Confidence legend

- **High** — read directly from decompiled code or resources; multiple independent sources agree. Rebuild-ready.
- **Medium** — evidence-backed inference (semantic labels over obfuscated names, single-source reads, or doc/code mismatches resolved by weight of evidence). Rebuild-ready with judgment.
- **Gap** — not determinable from this build; listed in `gaps.md` with what was tried. Design decisions required.

## Completeness audit (run 2026-10-22, Part 8 §4.0)

| Check | Result |
| --- | --- |
| Every feature area in `REFERENCE/index.md` (12 core docs, 5 guides, 13 Android/iOS how-tos, 3 troubleshooting, template gallery) → present in `features.md` or `gaps.md` | ✅ PASS — 14 areas / 62 features; 4 items are iOS-only (marked), template gallery = website-only (gaps G-C3) |
| Every distinct screen in `REFERENCE-IMAGES/index.md` (23 screenshots) → present in `ui.md` | ✅ PASS — all 23 referenced; 4 iOS-only rows flagged (iCloud Sync, Live Activity, Use-as-System-Alarm, Badge) |
| Every FINDINGS GAPS entry (data-model G1–G9, engine G1–G6, background G1–G5, ui G1–G5, settings-sounds-pro G1–G4) → consolidated in `gaps.md` | ✅ PASS — 29 entries consolidated into 21 items (several resolved during Part 8: see `gaps.md` §"Resolved during synthesis") |
| Every "documented" feature in `features.md` carries a findings citation | ✅ PASS — audit note per section |

## Contradiction resolutions applied (details in `gaps.md`)

1. **Autocompletion delay**: help doc says "resets 10 seconds after finish"; code computes `max(alertLead, 5 s) − 1 s`. Code wins; flagged G-E3.
2. **Custom-sound persistence**: Part 3 G6 "not found" superseded by Part 5 §5.0 — imported sounds are **cache-dir files** referenced by descriptor.
3. **`y7pr`/`m4ss`/`us5k` stores**: Part 5 mislabeled them dead; Part 7 corrected — they are live Play-billing stores. Corrected version used throughout.
4. **Template gallery**: no app-side store (Part 3 G8) — resolved: gallery is website-only; the Android app has no template feature.
5. **Free-tier history**: doc phrasing "stored only until the next start" is imprecise; code behavior (free keeps only the newest event) is authoritative.
