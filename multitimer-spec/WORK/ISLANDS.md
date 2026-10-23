# ISLANDS — top-level package classification

Part 2 · 2026-10-22 · APK: `com.persapps.multitimer` v1.14.1 (282) (per `WORK/APK-INFO.md`)
Source: `WORK/decompiled/jadx/sources/` (jadx 1.5.6 tree), file counts = `.java` files per bucket.

| Package (top-level bucket) | Files | Class | Role (1 line) |
| -------------------------: | ----: | ----- | ------------- |
| `defpackage` | 6,460 | **MIXED-OBF** | R8-flattened pool: the app's own logic (engine, data, settings) **and** renamed SDK leftovers; 1–3-char names, no package hierarchy. See §"defpackage" below. |
| `com/google/android` | 502 | SDK — google (gms, firebase datatransport, material, adservices) | Google Play services + Firebase transport + Material components |
| `androidx` | 103 | SDK — androidx | appcompat/fragment/media/window/room-runtime etc. (survivors with readable names) |
| `com/persapps/multitimer` | 78 | **APP** | The app's readable shell: manifest components, activities, services, receivers, custom views, appwidgets |
| `com/tenjin/android` | 76 | SDK — analytics (Tenjin) | Attribution/analytics SDK (has own Room queue `QueueEvent`) |
| `android` | 27 | SDK — androidx-legacy (`android.support.v4` parcelizers/media-session stubs) | Old support-lib classes kept for Parcelable compat |
| `com/google/firebase` | 22 | SDK — firebase | Firebase core/crash-adjacent bits |
| `com/pairip/licensecheck` | 9 | SDK — licensing (PairIP) | **Pro/licensing check** — relevant to Part 7 pro-gating |
| `com/android/installreferrer` | 8 | SDK — install-referrer | Play install referrer |
| `com/android/billingclient` | 3 | SDK — billing (Play Billing) | Subscriptions/one-time Pro purchase — Part 7 |
| `com/tbuonomo/viewpagerdotsindicator` | 1 | SDK — UI widget | ViewPager dots indicator |
| `com/google/gson` | 1 | SDK — json (gson) | Gson TypeAdapterFactory stub |
| `com/pairip/application` | 1 | SDK — licensing (PairIP) | PairIP helper |
| `com/instacart/library` | 1 | SDK — UI widget | Rounded ImageView |
| `com/github/rongi` | 1 | SDK — UI widget | Expandable TextView |
| `okhttp3` | 1 | SDK — networking (okhttp) | survivor; bulk of okhttp is inside `defpackage` |
| `kotlin` | 1 | SDK — kotlin stdlib | survivor; bulk of kotlin/coroutines is inside `defpackage` |

Total: 7,295 `.java` files. Every top-level bucket under `sources/` appears exactly once.

## The `defpackage` island (the real app body)

R8 full-mode flattened everything it renamed into one package-less pool (`sources/defpackage/a.java … zz9.java`, names 1–3 chars). The readable `com.persapps` island is only the **manifest-visible shell**; business logic lives here:

- `defpackage/mr2.java` — the app's SQLite/Room schema: 8 tables (`d3um, ti9i, hf5k, t3bh, mq3x, y9er, r6vk, ed1j`), obfuscated column names, types/PKs intact (99 lines)
- `defpackage/d72.java` — export JSON writer with obfuscated keys (`"e2kh"`, `"g5vs"`, …)
- `defpackage/db1.java`, `mo2.java`, `qu.java`, `m6.java`, `lz3.java`, `fz5.java` — AlarmManager/elapsedRealtime users (engine/alert candidates for Parts 4–5)
- `defpackage/nl2.java`, `ap2.java`, `ec4.java`, `li2.java`, `bp2.java`, `zo2.java` — MediaPlayer/SoundPool/Ringtone users (sound/alert candidates)
- `defpackage/l9.java`, `h63.java` — SharedPreferences stores (`"app_set_id_storage"`, `"e4eh"`, `"nz67"`, `"ei4h"`)

**Consequence for all parts:** a class being "the app" cannot be decided by package name alone inside `defpackage`; anchor on readable shell classes' imports (e.g. `AlertForegroundService` imports `lv4, nj, u63, vz3, w30, yc0`) and on resource/DB/string cross-references.
