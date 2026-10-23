# FINDINGS — Exclusions (Part 7)

Part 7 · 2026-10-22 · APK: `com.persapps.multitimer` v1.14.1 (282)
Definitive "ignore forever" list for later phases, from `WORK/ISLANDS.md` §1 (top-level classification) + Part 2/5 sweeps. Rule: these packages are vendored SDKs — never reverse them, never port them, never attribute app behavior to them. Two exceptions are *catalogued* here (billing, PairIP) because Part 7 needed them; they are still not rebuild targets.

| Package / store | Class | Verdict | One line |
| --- | --- | --- | --- |
| `com.google.android.*` (502 files: gms, firebase datatransport, material, adservices) | SDK — Google | **IGNORE** | Play-services + Material + adservices runtime; app logic never depends on gms features (Part 5 §6.0 network sweep). Material `com.google.android.material` is the one bit a UI rebuild replaces with its own components. |
| `com.google.firebase.*` (22) | SDK — Firebase | **IGNORE** | Core/transport bits; no app code. |
| `androidx.*` (103 readable) | SDK — AndroidX | **IGNORE** (rebuild replaces) | appcompat/fragment/media/room-runtime etc. |
| `android.support.*` remnants (27) | SDK — legacy | **IGNORE** | Parcelable/media-session compat shims. |
| `com.tenjin.android` (76) | SDK — analytics/attribution | **IGNORE — REMOVE in rebuild** | Install-attribution SDK with its own Room `QueueEventDatabase` (`z90`-adjacent); reports install/commerce events, not user data (Part 3 §3.0 SDK stores). |
| `com.android.installreferrer` (8) | SDK — install referrer | **IGNORE — REMOVE** | Play install-referrer client; used once at app start (`AppContextInstance.onCreate`, `km1` referrer_reported). |
| `com.android.billingclient` (3 + `res/raw/*.binarypb`) | SDK — Play Billing | **CATALOGUE, then REPLACE** | Pro licensing transport (Part 7 §3.1); a rebuild must re-implement licensing against its own store listing — the SDK itself is never copied. |
| `com.pairip.licensecheck` / `com.pairip.application` (10) | SDK — licensing/integrity | **CATALOGUE, then REPLACE** | PairIP app-integrity/license wrapper (Play App Signing anti-tamper); orthogonal to the feature pro-flag (`gj`/`cl3` — Part 7 §3.1). |
| `okhttp3` (1 readable; bulk inside `defpackage`) | SDK — networking | **IGNORE** | No app-feature HTTP anywhere (Part 5 §6.0) — okhttp serves the SDKs above. |
| `com.google.gson` (1) | SDK — JSON | **IGNORE** | TypeAdapter stub; app JSON is org-json based. |
| `com.tbuonomo.viewpagerdotsindicator` (1) | SDK — UI widget | **IGNORE** | Board page-dots indicator library (Part 6 §1.0 `dot_layout` consumer). |
| `com.instacart.library` (1) | SDK — UI widget | **IGNORE** | Rounded-image helper. |
| `com.github.rongi` (1) | SDK — UI widget | **IGNORE** | Expandable text view. |
| `kotlin*` (1 readable; bulk inside `defpackage`) | SDK — stdlib/coroutines | **IGNORE** | Runtime, not app code. |
| `defpackage` SDK remnants | MIXED-OBF | **IGNORE per-name** | Inside the 6,460-class pool: okhttp/kotlin/gms/firebase/tenjin/room-generated classes; app-vs-SDK split heuristic in `WORK/ISLANDS.md` §"defpackage" — the Parts 3–7 findings already cite only app-side classes. |
| SDK-owned preference stores | data | **IGNORE** | `app_set_id_storage`, `install_referrer_tracker`, `com.google.android.gms.measurement.prefs`, `google.analytics.deferred.deeplink.prefs`, `com.google.firebase.crashlytics`, `com.google.android.gms.signin`, Tenjin `INSTALL_PREFERENCE` (`FINDINGS/data-model.md` §3.0 tail). |
| Ads SDKs | — | **NONE PRESENT** | No ad-network packages exist (no admob/applovin/unity-ads etc. in the manifest or dex tree); `ACCESS_ADSERVICES_*` permissions serve the Android AdServices platform APIs only. |
| Crash SDKs | — | **NONE MATERIAL** | No Crashlytics application code found (firebase core bits only, no crash reporting wiring); `WRITE_EXTERNAL`/logging is local diagnostics (Part 5 §2.1 `qu.N`, §6.0). |

**Sync answer cross-reference:** no network feature exists in app code (Part 5 §6.0) — nothing in this list uploads timers/history; Tenjin/Billing/Firebase transport carry only SDK-internal events.
