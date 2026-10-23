# MAP — decompile inventory, obfuscation rating, recon targeting

Part 2 · 2026-10-22 · APK: `com.persapps.multitimer` v1.14.1 (282) (per `WORK/APK-INFO.md`)
Trees: `WORK/decompiled/jadx/` (jadx 1.5.6, `--show-bad-code -j 4`) and `WORK/decompiled/apktool/` (apktool 3.0.3, full decode). Input = base APK `APK/com.persapps.multitimer.apk` (single `classes.dex`).

## 1.0 Decompile status

| Tool | Output | Result |
| ---- | ------ | ------ |
| apktool | `WORK/decompiled/apktool/` | clean; 7,695 `.smali`; res fully decoded (readable layout/menu/xml names, `strings.xml` 540 entries) |
| jadx | `WORK/decompiled/jadx/sources/` | 7,295 `.java`; **finished with errors, count: 103 — all METHOD-level** (73 `JadxOverflowException`, 13 `JadxRuntimeException`, 9 types-fix, 2 StackOverflow; typical of R8 control-flow flattening). Per-method list + affected classes: `WORK/JADX-FAILED-CLASSES.txt` (60 classes). Class files still exist with `/* JADX ERROR */` markers at failed methods; fallback = smali in `WORK/decompiled/apktool/smali/` (CONVENTIONS §7.0). Note: `defpackage/vz3` (imported by `AlertForegroundService`) has 2 failed methods → Part 5 will need smali there. |

## 2.0 Inventory

### 2.1 Code file counts per top-level package
See `WORK/ISLANDS.md` for the full classification table (17 buckets, 7,295 files). Headline: **6,460 files sit in `defpackage`** (R8-flattened pool holding the app's real logic + renamed SDK remnants); the readable app shell `com/persapps/multitimer` is only **78 files**.

### 2.2 Native libraries
Base APK contains **no `lib/`** — native libs live in the XAPK ABI splits and are only two stock AndroidX helpers:
`libandroidx.graphics.path.so` (~10 KB), `libdatastore_shared_counter.so` (~7 KB) per ABI (arm64-v8a, armeabi-v7a).
**No custom native code → nothing material is out of jadx's reach.** (Native analysis remains out of scope per CONVENTIONS §7.0.)

### 2.3 Assets & res/raw
- `assets/`: `PublicSuffixDatabase.list` (okhttp), `certs/`, `dexopt/`, `supplierconfig.json` (firebase transport) — no app content
- `res/raw/`: **`alarm_1s.mp3`, `alarm_6s.mp3`** (the 2 default alert sounds — matches help doc "There are 2 sounds in the library by default"), plus billingclient protobufs
- `res/` dirs of note: `layout/` (198 files), `layout-land/`, `layout-watch/`, `menu/`, `values/` (+night, land, port, sw600dp, watch variants), `xml/` (widget infos, file_provider_paths, network_security_config)

### 2.4 Manifest digest (`WORK/decompiled/apktool/AndroidManifest.xml`)
**Permissions (23):** INTERNET, ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE · FOREGROUND_SERVICE, FOREGROUND_SERVICE_MEDIA_PLAYBACK · WAKE_LOCK, USE_KEYGUARD · SCHEDULE_EXACT_ALARM, USE_EXACT_ALARM, RECEIVE_BOOT_COMPLETED, QUICKBOOT_POWERON · POST_NOTIFICATIONS, ACCESS_NOTIFICATION_POLICY, USE_FULL_SCREEN_INTENT, VIBRATE · MODIFY_AUDIO_SETTINGS, READ_MEDIA_AUDIO · ACCESS_ADSERVICES_AD_ID/ATTRIBUTION · com.android.vending.BILLING, com.android.vending.CHECK_LICENSE, BIND_GET_INSTALL_REFERRER_SERVICE, DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION (app-scoped)

**Components — app (31 activities / 2 services / 10 receivers / 0 providers):**
- Entry: `use.ui.scene.main.MainActivity` (exported, LAUNCHER)
- Editor family: `use.ui.insteditor.MTInstrumentEditorActivity` + sub-screens (alert, repeats, color, note, intervals, clock/timezone, countdown TimeValue, countup Notices, interval MTIntervalTimerEntry, buttons, add-time/add-amount)
- Scenes: `single.MTSingleViewActivity`, `history.HistoryActivity`, `icon.IconsActivity`, `pro.ProVersionActivity`, `settings.{Alert,Controls,Extra,History}SettingsActivity`, `settings.DeletedDataActivity`, `sounds.{Sounds,TextToSpeech}Activity`, `welcome.WelcomeActivity`
- App widgets (exported): `use.appwidget.{mini1,mini2,single}` settings + `quick.AWQuickStartActivity`; receivers `id.AppWidget_{m5rb,sz2x,u7lv}`, `id.br_i9fa`
- Background services: `app.AppBootJobService`, `module.alert.AlertForegroundService` (the alert player)
- Receivers (scheduling core): `app.AppBootReceiver`, `module.scheduler.SystemScheduleReceiver`, `module.notice.NoticeReceiver`, `module.notice.event.AlertRepeatReceiver`, `module.notice.state.ScheduleReceiver`, `module.events.InstrumentEventsScheduleReceiver`
- Library components (5 act / 7 svc / 4 prov / 4 rec): google play-services, firebase datatransport, billing, installreferrer, androidx startup/emoji2 — ignore for recon.

**Domain vocabulary:** the internal name for a timer is **"instrument" (MTInstrument*)**; boards = timer boards; "inst" abbrev. in editor packages.

## 3.0 Obfuscation assessment → **HEAVY** (with strong surviving anchors)

Evidence (sampled ≥10 classes):
1. **APP class names:** manifest-visible shell readable (`AlertForegroundService`, `MTInstrumentEditorActivity`, `ProVersionActivity`, `HistoryActivity`, `SoundsActivity`, `TextToSpeechActivity`, `AppBootJobService`, `SystemScheduleReceiver`, `AWMini1SettingsActivity`, `DeletedDataActivity`, `WelcomeActivity`, `MTSingleViewActivity`) — 78 files readable. **Everything else renamed**: 6,460 classes in `defpackage` with 1–3-char names (`a.java, a0.java … zz9.java`), no hierarchy.
2. **Method/field names:** do NOT survive — even in readable app classes: `AlertForegroundService` has fields `n,o,p` and method `a()`; it constructs `defpackage.u63` (a NotificationCompat builder wrapper) setting fields `icon,e,g,m,i,r,c,u`. `/* JADX INFO: compiled from: r8-map-id-… */` confirms R8 mapping absent.
3. **Resource names:** layout/menu/xml **filenames readable** (`a_editor_alert_activity.xml`, `main_board_default.xml`, `single_options.xml`, `sounds_options.xml`); `strings.xml` **keys obfuscated** (`a0iz`) but **values fully readable English** (540 strings, incl. timer-type descriptions "Countdown timer", "Pomodoro timer", "Interval"…).
4. **DB / prefs / constants:** app DB schema present as raw SQL in `defpackage/mr2.java` — 8 tables `d3um, ti9i, hf5k, t3bh, mq3x, y9er, r6vk, ed1j`; **table/column names obfuscated**, types/PKs intact. Preference store names mostly obfuscated (`"nz67"`, `"ei4h"`, `"e4eh"`; one readable `"app_set_id_storage"`). Export JSON keys obfuscated (`"e2kh"`, `"g5vs"`… in `defpackage/d72.java`).

**Implications per recon area:**
- **Data model (Part 3):** cannot come from type names. Build from `mr2.java` SQL schema + column-type/PK structure + how shell classes read/write it + export/import code paths; cross-check against help docs. Expect to label tables semantically by evidence, not names.
- **Engine (Part 4):** logic in `defpackage`; anchor via readable receivers/services and their import lists; `elapsedRealtime`/`AlarmManager` call sites are the entry points.
- **Alerts (Part 5):** strongest anchors — `AlertForegroundService` readable end-to-end + notification-channel users + MediaPlayer/SoundPool users list (below).
- **UI (Part 6):** layouts readable by filename + 52 shell files use `R.layout` → map layouts↔activities cheaply.
- **Pro/settings (Part 7):** billing + PairIP license SDKs visible; `ProVersionActivity`/`ProVersionFragment` readable.

## 4.0 Where to look (per upcoming part)

### Part 3 — data model
- Schema: `defpackage/mr2.java` (99 ln, 8 CREATE TABLE); also `sz3.java` (firebase transport — ignore), tenjin `QueueEventDatabase_Impl` (ignore)
- Room runtime present (`androidx/room`); find DB open/migrations: `rg -l "onCreate|onUpgrade|identity_hash" WORK/decompiled/jadx/sources/defpackage`
- Export/import: `defpackage/d72.java` (writer), `rg -l "JSONObject|JSONArray" sources/defpackage | head` + shell `how-to-import` path via `MainActivity` menu handlers
- Preference stores: `defpackage/l9.java` (`"app_set_id_storage"`), `h63.java` (`"e4eh"`), `WelcomeActivity` (`"nz67"`), `ControlsSettingsActivity` (`"ei4h"`)

### Part 4 — timer engine
- Receivers (readable): `module.scheduler.SystemScheduleReceiver`, `module.notice.state.ScheduleReceiver`, `module.events.InstrumentEventsScheduleReceiver`, `module.notice.event.AlertRepeatReceiver`
- `elapsedRealtime` users: `defpackage/db1.java` (+ shell); `AlarmManager` users: `defpackage/{mo2,qu,m6,lz3,fz5}.java`
- Instrument model: `rg -n "instrument" WORK/decompiled/jadx/sources/defpackage/d72.java` and `rg -l "MTInstrument" sources/com/persapps` (editor + single view)

### Part 5 — background & alerts
- `com/persapps/multitimer/module/alert/AlertForegroundService.java` (readable; builds channel `"a7fg"`, uses `defpackage.{lv4,nj,u63,vz3,w30,yc0}`)
- `app/AppBootJobService.java`, `app/AppBootReceiver.java` (boot restore)
- Notification channels: `rg -l NotificationChannel sources/defpackage` → `p10, vn2, c73, r63, i3.java`
- Sound playback: `defpackage/{nl2,ap2,ec4,li2,bp2,zo2}.java` (MediaPlayer/SoundPool/Ringtone); default sounds `res/raw/alarm_{1s,6s}.mp3`; TTS: `use.ui.scene.sounds.TextToSpeechActivity`
- Full-screen intent: `USE_FULL_SCREEN_INTENT` permission → find with `rg -l "setFullScreenIntent" sources`

### Part 6 — UI
- Layouts↔activities: 52 shell files reference `R.layout`; layouts named semantically in `WORK/decompiled/apktool/res/layout/` (198)
- Main workspace: `use.ui.scene.main.MainActivity`, `use.ui.workspace.instrument.MTInstrumentView`, `use.ui.scene.single.MTSingleViewActivity`
- Editor tree: `use.ui.insteditor.*` (property views name every editor feature: MTAlertPropertyView, MTBoardPropertyView, MTColorPropertyView, MTIconPropertyView, MTNamePropertyView, MTSoundPropertyView, DurationPropertyView, …)
- Strings: `WORK/decompiled/apktool/res/values/strings.xml` (readable values; grep by visible text to find keys)
- Widgets: `use.appwidget.*` + `res/xml/app_widget_*_info.xml`

### Part 7 — settings, sounds, pro-gating
- Settings shell: `use.ui.scene.settings.*` + `AlertSettingsActivity`, `ExtraSettingsActivity`, `ControlsSettingsActivity`, `HistorySettingsActivity`
- Pro: `use.ui.scene.pro.{ProVersionActivity,ProVersionFragment,view.FeatureView,view.OfferView}`; billing call sites `rg -l "BillingClient|queryPurchases" sources` → `defpackage/{db1,l9,ti5,qi5,ys}.java`; PairIP licensing `com/pairip/licensecheck/LicenseClient.java`
- Sounds: `use.ui.scene.sounds.SoundsActivity` + custom-sound import (`READ_MEDIA_AUDIO` permission; help doc how-to-add-custom-sounds)
- Pro-gate checks: `rg -n "isPro|pro\b" sources/com/persapps` (expect obfuscated flags — confirm via call sites in readable activities)

## 5.0 GAPS
- jadx failed 103 methods across 60 classes (list in `WORK/JADX-FAILED-CLASSES.txt`); smali fallback available, not yet exercised
- `defpackage` app-vs-SDK split is heuristic (import-graph anchored), not exact — SDK remnants inside the pool (okhttp/kotlin bulk) inflate "app" appearance
- Native: none material (stock AndroidX .so only) — nothing hidden there
- XAPK config splits (dpi/locale) not decoded — resource values identical to base except locale/dpi variants

## 6.0 CONFIDENCE
**High** for inventory/manifest/resources facts (direct command output). **High** for the obfuscation rating (sampled both islands + resources + DB + prefs). **Medium** for the specific "where to look" file guesses (rg -l evidence, not yet read end-to-end — that's Parts 3–7's job).
