# APK-INFO — pinned analysis target

> **VERSION PIN (D7): v1.14.1 (282) ACCEPTED by user 2026-10-22.** All parts analyze this build.

## 1.0 APK identity (gate PASSED 2026-10-22)

| Field | Value |
| ----- | ----- |
| Package | **`com.persapps.multitimer`** (MultiTimer: Multiple Timers, Sergey Astakhov / Persapps) |
| versionName | **1.14.1** |
| versionCode | **282** |
| minSdk | 32 (Android 12L) |
| targetSdk | 36 |
| compileSdk | 36 |
| Launcher | `com.persapps.multitimer.use.ui.scene.main.MainActivity` |
| Application file | `APK/multitimer-multiple-timers-1-14-1.xapk` (6,487,761 B) — split-APK bundle (APKPure-style: base + ABI/DPI/language config splits) |
| sha256 (xapk) | `525c171da950ea0ca0533cecd0b879594f11a417b778c938edb97ad0e298edcc` |
| Analysis APK | `APK/com.persapps.multitimer.apk` (10,056,907 B) — base APK extracted from the xapk; contains all code (single `classes.dex`) + resources |
| sha256 (base apk) | `4cff45f47fb1384003fb7e3c5d46564d0a2f87cc77db92eb99bbab5b2ae8e236` |
| Config splits | left inside the xapk (arm64-v8a/armeabi-v7a, dpi splits, fr/es/ar/ru/de/pt/tr/it language splits); no code in them — Part 2+ works against the base APK only |
| Manifest decode evidence | `WORK/apk-manifest-check/` (apktool 3.0.3, `-s` no-smali) |

## 2.0 Installed tools (verified working)

| Tool | Version | Invocation |
| ---- | ------- | ---------- |
| jadx | 1.5.6 (CLI, official `jadx-1.5.6.zip`) | `WORK/tools/jadx/bin/jadx --version` → `1.5.6` |
| apktool | 3.0.3 | `WORK/tools/apktool --version` → `3.0.3` (local wrapper `WORK/tools/apktool`; finds `WORK/tools/apktool_3.0.3.jar` in same dir) |

Both from official GitHub releases (skylot/jadx v1.5.6; iBotPeaches/Apktool v3.0.3), downloaded 2026-10-22.

## 3.0 Version currency (for user acceptance checkpoint)

| Source | Version | Date | URL |
| ------ | ------- | ---- | --- |
| Downloaded APK | **1.14.1 (282)** | file mtimes in xapk: 2026-10-10/19 | `APK/` |
| Google Play listing | (versionName not published) "Updated on" **Oct 5, 2026** | — | https://play.google.com/store/apps/details?id=com.persapps.multitimer |
| APKPure mirror | **1.14.1** | uploaded Oct 10, 2026 | https://apkpure.com/multi-timer-multiple-timers/com.persapps.multitimer |
| Uptodown mirror | **1.14.1** | file dated Oct 19, 2026 | https://multitimer.en.uptodown.com/android |
| Help-center release notes (Android) | stale — newest version mentioned **1.2.1** | page not maintained | `REFERENCE/home-whats-new-android.md` |
| Softpedia (plan's original candidate) | not used — user sourced from split-XAPK mirror instead | — | https://mobile.softpedia.com/apk/multitimer/ |

**Read:** downloaded 1.14.1 == newest version on every live source; Play "Updated on" (Oct 5) predates the mirror uploads (Oct 10–19), consistent with the same release. **Likely current.** Acceptance is the user's checkpoint (D7).
Note: APKMirror does **not** carry this package (OVERVIEW §7.0's alternate-source suggestion is void; APKPure/Uptodown are the mirrors).

## 4.0 History

- 2026-10-22 first run: supplied file was the Uptodown App Store client (`com.uptodown` 7.41) — wrong app, gate failed → BLOCKERS.md B1. Resolved same day when user supplied the correct 1.14.1 XAPK.
