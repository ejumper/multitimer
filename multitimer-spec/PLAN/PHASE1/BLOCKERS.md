# BLOCKERS — Phase 1

## B1 — Part 1, §3.2 APK identity gate FAILED (2026-10-22) — **RESOLVED same day**

**Resolution:** user re-downloaded the correct app as `multitimer-multiple-timers-1-14-1.xapk` (split-APK bundle). Base APK extracted to `APK/com.persapps.multitimer.apk`; gate re-checked and PASSED (`com.persapps.multitimer`, v1.14.1/282). Part 1 completed. Details in `WORK/APK-INFO.md` §4.0.

**What I was doing:** Verifying the user-supplied APK `APK/uptodown-com.persapps.multitimer.apk` per PH1PART1 §3.2 (gate: package MUST be `com.persapps.multitimer`).

**Exact commands / evidence:**
- `WORK/tools/apktool d -s -f APK/uptodown-com.persapps.multitimer.apk -o WORK/apk-manifest-check` → succeeded, decoded fine.
- Decoded `AndroidManifest.xml`: `package="com.uptodown"`; `<application android:name="com.uptodown.UptodownApp" android:icon="@mipmap/ic_launcher_uptodown" …>`; all activities are `com.uptodown.activities.*`; `res/values/strings.xml`: `<string name="app_name">Uptodown App Store</string>`.
- `apktool.yml`: versionCode 741, versionName **7.41**, minSdk 23, targetSdk 36.
- `grep -c persapps AndroidManifest.xml` → 0; `strings` over all 4 classes*.dex → zero hits for `persapps` or `multitimer`.

**What I expected:** package `com.persapps.multitimer`, versionName ~1.x (MultiTimer's real versioning).

**What happened:** The file is the **Uptodown App Store client app itself**, not MultiTimer. Known Uptodown download quirk: their "secure download" flow serves their own store app when the direct APK isn't taken correctly. The filename (`uptodown-com.persapps.multitimer.apk`) reflects the intended target, not the content.

**Attempts made (3):** manifest decode + package check; resource-string check (`app_name`); dex-wide string scan for persapps/multitimer. All three agree: wrong app. Not a decode artifact.

**Action taken:** STOPPED Part 1 per §3.2 gate + CONVENTIONS §4.0. Tools (jadx 1.5.6, apktool 3.0.3) are installed and verified — that work stands. Reference prefetch (§3.4/§3.5) NOT started.

**For the user (re-download guidance):**
- Real MultiTimer current version: **1.14.1**, Play "Updated on Oct 5, 2026" (APKPure upload Oct 10 2026; Uptodown file Oct 19 2026). APKMirror does **not** carry this app.
- Suggested sources: Uptodown's *direct* APK link (right-click "Download" → copy link, bypass the store-app installer), or APKPure (`com.persapps.multitimer`). Verify the downloaded file's size/name before dropping into `APK/`.
- After correct APK is in `APK/` (and the wrong file removed or renamed aside), re-run Part 1 — tool install can be skipped.
