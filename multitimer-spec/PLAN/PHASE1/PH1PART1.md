# PH1PART1 — Setup, APK Verification, Reference Prefetch

Part of [Phase 1](./OVERVIEW.md). [CONVENTIONS.md](./CONVENTIONS.md) binds this task.

## 1.0 Objective

Install decompilation tooling, verify the user-supplied APK is the right app and record
its identity/version, and pre-fetch the official documentation as ground-truth
reference material.

## 2.0 Prerequisites (STOP if unmet)

- An app package file (`.apk` or `.xapk`) exists in `./APK/`. Expected: MultiTimer
  1.14.1 **XAPK** from Uptodown. If the only file present is the Uptodown store
  client itself (package `com.uptodown`, versionName 7.x — a known download quirk),
  treat that as MISSING: STOP and ask the user to re-download via "All variants".
- If no package file at all: STOP and report — the user must download it (they are
  the only step allowed to fetch the app).

## 3.0 Procedure

### 3.1 Install tools

1. jadx (latest stable zip, NOT a `-nojr`/gui-only variant) from
   https://github.com/skylot/jadx/releases → unzip to `WORK/tools/jadx/` → verify
   `WORK/tools/jadx/bin/jadx --version`.
2. apktool (wrapper script + jar, latest) per https://apktool.org/install → verify
   `apktool --version`. If system-wide install is awkward, a local `WORK/tools/apktool`
   wrapper is fine — record the invocation path in `WORK/APK-INFO.md`.

### 3.2 Verify APK identity

1. `sha256sum APK/*` → record (every file in APK/).
2. **If the package is an `.xapk`** (a zip containing the real APK + config splits):
   `unzip` it into `WORK/xapk-extract/`, then locate the **base APK** inside — the
   `.apk` whose manifest passes the gate below (typically the largest / named for the
   package). Record the base APK filename + its sha256 too, plus its full path —
   later parts use this path. Config splits (`config.*`) are IGNORED for this
   project. If it is already a plain `.apk`, use it directly.
3. Decode manifest only (fast, no smali) on the base APK:
   `apktool d -s -f <base-apk> -o WORK/apk-manifest-check`
4. From `WORK/apk-manifest-check/AndroidManifest.xml` + `apktool.yml` record:
   package name, versionName, versionCode, minSdk/targetSdk.
5. **Gate:** package MUST be `com.persapps.multitimer`. Anything else → BLOCKERS.md, STOP.
   Expected versionName: 1.14.1 (Play last updated 2026-10-05; AppBrain shows 1.14.1
   released 2026-09-24). A version mismatch is reportable, not fatal — note it.

### 3.3 Version currency check (assists the user's D2 confirmation)

Using web access (fetcher sub-session is fine):
1. Current listing info from the Google Play page for `com.persapps.multitimer`
   (at minimum the "Updated on" date).
2. Version shown on the user's download source page (softpedia:
   https://mobile.softpedia.com/apk/multitimer/) — was the downloaded file's page
   version recorded? Compare against decoded versionName.
3. help.multitimer.net — check for a changelog / release notes / "what's new" page;
   record latest mentioned version if any.
Write the comparison into `WORK/APK-INFO.md` under a "Version currency" section with
dates + URLs. Do NOT decide acceptance — that is the user's checkpoint.

### 3.4 Prefetch reference docs

1. Fetch help.multitimer.net — homepage, sitemap or nav structure, then EVERY article
   page linked from it (they describe features; this is our feature checklist).
2. Fetch multitimer.net marketing pages that describe features.
3. Save each page as markdown in `REFERENCE/`: kebab-case name derived from the page
   title, one page per file.
4. Write `REFERENCE/index.md`: table of every page (title, URL, saved filename, one-line
   summary of what it covers).

### 3.5 Prefetch method references (RE technique guides)

Fetch this curated set into `REFERENCE/method/` (kebab-case, same rules) — they are
the executor's offline answers to "how do I handle X" snags in Parts 2–7:

- https://mas.owasp.org/MASTG/techniques/android/MASTG-TECH-0014/ — OWASP MASTG,
  static analysis on Android (entry point; ignore the security-testing framing)
- https://www.ragingrock.com/AndroidAppRE/ — Maddie Stone's Android App RE 101 index,
  PLUS its chapters: `app_fundamentals.html`, `reversing_intro.html`,
  `reversing_dex.html`, `obfuscation.html`
- https://httptoolkit.com/blog/android-reverse-engineering/ — practical
  jadx workflow (extract → find → understand)

Note in `REFERENCE/method/README.md` (2 lines): Frida/dynamic-analysis and
Ghidra/native-library material in these guides is OUT OF SCOPE for this project.
Add the method pages to `REFERENCE/index.md` too.

## 4.0 Deliverables

| File | Content |
| ---- | ------- |
| `WORK/APK-INFO.md` | sha256 (all package files + base APK), package, versionName/versionCode, SDK levels, base-APK path (later parts use this), tools+versions installed, version-currency comparison |
| `REFERENCE/*.md` + `REFERENCE/index.md` | Help-center/site docs, indexed |
| `REFERENCE/method/*.md` | Curated RE technique guides (§3.5) |

## 5.0 Self-Verification Checklist

- [ ] `jadx --version` and `apktool --version` both succeed (exact invocations recorded)
- [ ] package name == `com.persapps.multitimer`
- [ ] APK-INFO.md has sha256 + versions + currency section
- [ ] REFERENCE/index.md lists every fetched page with URL
- [ ] No reference page failed to fetch silently (failures listed in index.md)
- [ ] `REFERENCE/method/` contains all 7 curated pages (MASTG ×1, AndroidAppRE ×5,
      httptoolkit ×1) or failures are reported

## 6.0 STOP

This part ends at a **user checkpoint**: report version-currency findings so the user
can accept the version or re-download. Include your read (e.g. "downloaded 3.x, Play
page updated 2026-xx, likely current/stale because …").
