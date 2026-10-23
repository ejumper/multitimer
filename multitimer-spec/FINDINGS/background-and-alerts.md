# FINDINGS — Background Operation & Alert Delivery (Part 5)

Part 5 · 2026-10-22 · APK: `com.persapps.multitimer` v1.14.1 (282) (per `WORK/APK-INFO.md`)
Anchors: `WORK/MAP.md` §3.0 components + §4.0 "Part 5" pointers; engine facts from `FINDINGS/engine.md` (Part 4). App file paths relative to `WORK/decompiled/jadx/sources/` unless marked `res/`. Only the two services and ten receivers declared for the app (manifest digest `WORK/MAP.md` §3.0) are in scope; Google/Firebase/billing SDK components are out (Part 2 classification).

## 1.0 Services

The app declares exactly **2 services** (`WORK/decompiled/apktool/AndroidManifest.xml`; both `exported=false`):

### 1.1 `com.persapps.multitimer.module.alert.AlertForegroundService` — the alert player host

Readable end-to-end (`com/persapps/multitimer/module/alert/AlertForegroundService.java`, 105 ln):

- **Foreground-service type `mediaPlayback`** (manifest attribute) — declared so audio keeps playing in background on Android 14+; permission `FOREGROUND_SERVICE_MEDIA_PLAYBACK` present (`AndroidManifest.xml`). Promotion wrappers: `nj.v`/`nj.w` = `startForeground(3701, notification, 2)` — id **3701**, type **2 = FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK** (`defpackage/nj.java:169-175`); pre-29 fallback plain `startForeground(3701, …)` (`AlertForegroundService.java:82-86`).
- **Its notification is deliberately silent and low-key**: channel `"a7fg"` named `R.string.app_name`, `IMPORTANCE_LOW (2)`? — created with importance literal `2`, `setSound(null,null)`, `enableVibration(false)`, `setShowBadge(false)` (`AlertForegroundService.java:59-65`); notification: small icon, title = app name, contentIntent = MainActivity, flag add `2` (ONGOING_EVENT), `u63Var.m="service"` (category field of the `u63` Notification wrapper — `AlertForegroundService.java:40-53`).
- **Who starts it:** `r62.d()` — the alert-session manager — on **SDK ≥ 37** starts the service via `startForegroundService` and suspends until the service reports running; on older Android versions it does not need the service and returns immediately (`defpackage/r62.java:93-121`: `if (Build.VERSION.SDK_INT < 37) objT = TRUE; else { … AlertForegroundService.o.add(waiter); context.startForegroundService(…) }`). `vz3.E()` (called from `onStartCommand`) flips the static running flag and releases the waiters with `TRUE`; `vz3.D()` / `onDestroy` release them with `FALSE` (`defpackage/vz3.java:92-119`, `AlertForegroundService.java:67-77`). Session end (`r62.a()`) stops the service again (`r62.java:48-56`).
- `onStartCommand` returns **`START_NOT_STICKY` (2)** (`AlertForegroundService.java:88`) and starts with `return 2` in both paths — a short-lived media host, not a persistent service.
- Net effect: **the service exists to satisfy Android 16+ (SDK 37) mediaPlayback FGS requirements while alarm sound plays**; on older systems all playback is done without it (see §5.0).

### 1.2 `com.persapps.multitimer.app.AppBootJobService` — reboot re-arm job

Plain `JobService` (`com/persapps/multitimer/app/AppBootJobService.java:35-66`), scheduled with id **25143**, `setMinimumLatency(1000)`, `setOverrideDeadline(10000)` by `AppBootReceiver` (§3.0). `onStartJob` does the full re-arm (§3.0) synchronously and returns `false` (work done).

## 2.0 Scheduling (alarms)

Two layers, both built on `AlarmManager` RTC_WAKEUP (`type 0`):

### 2.1 `lz3` — the generic alarm core

`defpackage/lz3.java` (166 ln, fully read):

- **Schedule `c(lh2 time, Intent payload)`** (`lz3.java:62-165`): key = `"intent(" + payload.filterHashCode() + ")"`; persists a descriptor {time `"qbr2"`, `intent.toUri()` `"ym4e"`} into prefs (`nz3.a` store) so the schedule survives process death (`lz3.java:151-164`); arms a `PendingIntent.getBroadcast` to **`SystemScheduleReceiver`** carrying extras `unq4` (key), `tri6` (epoch-millis), `nni4` (the embedded payload `Intent`), FLAG_IMMUTABLE (`lz3.java:90-98`).
- **Alarm-kind strategy — user-selectable, Doze-proof either way** (`lz3.java:99-147`):
  - pref **`ozi7` == true** (exact-alarm mode): `setExactAndAllowWhileIdle(0, t, pi)`; on SDK ≥ 31 without `canScheduleExactAlarms()` → degrade to `setAndAllowWhileIdle` (`lz3.java:100-107`, log `"not a possible option"`).
  - pref **`ozi7` == false** (default): **`setAlarmClock(new AlarmClockInfo(t, MainActivity-pendingIntent), pi)`** (`lz3.java:110-125`) — the alarm-clock API (Doze-exempt, shows the system alarm icon); on exception → `setExactAndAllowWhileIdle` → `setAndAllowWhileIdle` fallback chain (`lz3.java:126-146`). The MainActivity passthrough intent carries extra `m6ah` = instrument id when the payload was an instrument event (`lz3.java:112-121`).
  - The pref `ozi7` lives in the store resolved by `AppContextInstance.c().f` (`defpackage/qu.java:375`: same read, `EXACT_AND_ALLOW_WHILE_IDLE` vs `ALARM_CLOCK` enum). Permissions `SCHEDULE_EXACT_ALARM` **and** `USE_EXACT_ALARM` are both declared (`AndroidManifest.xml`) — the latter is auto-granted for alarm-clock apps.
- **Delivery `b(id, time, payload)`** (`lz3.java:43-60`): if fired ≥ 2 s early (`time − now ≥ 2000`) → silently **re-schedule** (`c`); else dispatch the embedded payload via `PendingIntent.send()`, with a per-key in-flight dedup set (`lz3.java:49-59`). This makes early deliveries impossible to double-fire.
- **Cancel `a(Intent)`** (`lz3.java:37-42`): `AlarmManager.cancel` by identical PendingIntent + drop the persisted descriptor.
- **Diagnostics**: every instrument-event delivery also records a device-state snapshot (scheduling model, notifications-enabled, power-save, interactive, app importance, battery/charging, Doze/light-idle/low-power-standby states, `canScheduleExactAlarms`, background-restriction) — `defpackage/qu.java:316-440` (`qu.N`, invoked from `InstrumentEventsScheduleReceiver`). This feeds the local diagnostics exporter (Part 3 §4.0 `logs.zip`), not any server.

### 2.2 `on1` — per-instrument timer-event scheduler (engine, Part 4 anchor)

`defpackage/on1.java` (140 ln, fully read):

- Registry: `km1(context,25)` → SharedPreferences **`bj1l`** (`defpackage/km1.java:79-96`, `defpackage/w6.java:104-106`) — keys = instrument ids, values = serialized `sn1` lists of scheduled `um2` events (Part 3 §3.0).
- **Re-arm rule: ONE alarm per instrument — only the single earliest pending event time; all events coinciding at that exact timestamp are coalesced into that one alarm** (`on1.d`, `on1.java:81-139`: min over `um2.c.a(now)`, `arrayList` collects equals only, single intent `f4js/<id>` with extras `j3yp`=id, `w8se`=JSON list, `n3gs`=time → `AppContextInstance.c().c(time, intent)` = `lz3.c`).
- **Delivery** (`on1.c`, `on1.java:35-77`): log `"EV receive event"` → publish `sm2` events onto the bus `rn1.c` (handler `qn1` applies to instruments — Part 4) → **immediately re-arm the next event** (`on1.java:72-76`).
- **Cancel** (`on1.a`, `on1.java:20-26`): cancel intent `f4js/<id>` through `lz3.a`.
- So: N timers ≈ N live alarms (one each), not one alarm for all timers, and not one per event.

### 2.3 The four non-event receivers (notification pipeline)

All readable, all thin dispatchers into `AppContextInstance` singletons (accessors mapped at `AppContextInstance.java:2366-2380`: `.a()`=`rn1` engine, `.b()`=`h63` notice subsystem, `.c()`=`lz3` alarm core):

| Receiver | Trigger | Extras → effect |
| --- | --- | --- |
| `module.scheduler.SystemScheduleReceiver` | every `lz3` alarm | `unq4`/`tri6`/`nni4` → `lz3.b(id, time, payload)` (`…/SystemScheduleReceiver.java:38-45`) |
| `module.events.InstrumentEventsScheduleReceiver` | payload of timer-event alarms (`f4js/<id>`) | `j3yp`/`w8se`/`n3gs` (legacy alt: `yu6s`) → per-event diagnostics `qu.N` → `on1.c(id, events, time)` (`…/InstrumentEventsScheduleReceiver.java:64-110`) |
| `module.notice.state.ScheduleReceiver` | NC countdown steps (`vd6w/<id>`) | `hec2`=id, `rkh5`=JSON {`n0fh` time, `n4vj` `im2` state} → `k63.b.a(id,time)` → `k63.c.e(...)` or async resolve → refresh/cancel ongoing notification; if NC master enabled also `k63.a/f` (`…/notice/state/ScheduleReceiver.java:38-58`) |
| `module.notice.event.AlertRepeatReceiver` | scheduled alert repeats | `xcp5`=id, `eq5v`=JSON event `sm2` {`iqs6` kind, `n6cy` time, `r8xq` version, `c76t` payload}, `oh5m`=repeat index → `e63.c(id, sm2, i)` (`…/notice/event/AlertRepeatReceiver.java:24-42`) |
| `module.notice.NoticeReceiver` | notification action buttons | action string `ud1r;<notifier>;<vl2-payload>` → execute notification action via `aa5.b`; or `w4oo;<id>` → `k63.e(id, hx0.n)` clear NC state (`…/notice/NoticeReceiver.java:40-52`) |

NC step scheduling itself: `ri0.e(id, jm2, id)` writes {`n0fh`, `n4vj`} and arms a `vd6w/<id>` alarm through `lz3.c` (`defpackage/ri0.java:85-104`).

## 3.0 Reboot / kill recovery — answered definitively

`AppBootReceiver` (`com/persapps/multitimer/app/AppBootReceiver.java:41-47`): on **`BOOT_COMPLETED`** (permission also paired with `QUICKBOOT_POWERON`) schedules the JobScheduler job **25143 → AppBootJobService** (1–10 s window). `AppBootJobService.onStartJob` (`AppBootJobService.java:36-56`):

1. Reads **`bj1l`** (scheduled-instrument registry) — `on1.b.J().getAll().keySet()` — and for every instrument with pending events: `on1.b.G(id)` (deserialize `sn1`) → `on1.d(id, sn1)` = recompute next occurrence from **wall-clock anchors** (Part 4 §2.3 — no elapsed-time state to restore) and re-register the alarm. Missed recurring cycles are handled at start time by the retroactive path (`ka2.E` past-start logic, Part 4 §2.4).
2. Calls `AppContextInstance.b().c().d()` = `k63.d()` — rebuilds the **notification-countdown** states: if master toggle `e4eh.sb4m` is set, re-reads all ids from prefs **`sy2f`** and re-schedules their next NC step (`defpackage/k63.java:60-77`), so running countdown notifications resume after reboot.
- Timer *state* itself is never persisted/restored by the boot path — it is recomputed from start/end wall-clock anchors in the documents (Part 4 §2.3); alerts that were interrupted are re-derived, not "marked interrupted" (no tombstone/quarantine code found).
- `onStopJob` returns `false` (no retry semantics needed; work is synchronous).

**Process kill (no reboot):** alarms survive (system-managed); in-flight playback dies with the process and is NOT resumed — nothing re-plays an interrupted alert (no code path replays past-due alerts; delivery is at-alarm-time only). Confidence high (no `ON_RESUME`-style catch-up except the delayed-start past-time path, Part 4).

## 4.0 Notifications

- **Channels** (`defpackage/p10.java:36-141` bootstrap `p10.a()`; registry persisted in prefs **`h1tf`** key `t2iz` — `defpackage/vn2.java:570-606`):
  - **`e1jo` = "Alarm"** — importance HIGH (4) (`defpackage/vn2.java:614-625`); alerts post here.
  - **`x78m` = "Status"** — importance LOW (2); ongoing countdown/state notifications.
  - **`a7fg`** = app-name channel for the FGS service notification (silent, §1.1).
  - Legacy ids `iof3`, `t30q`, `s8pu` are looked up and recorded for migration/cleanup (`p10.java:45-62`); channel group `dlh6` (`p10.java:70-72`). Channels carry **no sound, no vibration, no lights** — `setSound(null, AudioAttributes(USAGE_NOTIFICATION_EVENT))`, `enableVibration(false)` (`vn2.java:617-625`): the app plays sound/vibration itself (§5.0).
- **Poster** `d73` (`defpackage/d73.java`): `b()` = one-time `cancelAll()` before posting a fresh alert set (`d73.java:158-170`); `a(request, model)` maps kind enum `p63`: **progress → channel `x78m`, category `"progress"`, priority 0; event/alarm → channel `e1jo`, categories `"event"`/`"alarm"`, priorities 1/2** (`d73.java:44-76`). State notifications use RemoteViews `R.layout.n_state_notification` with a **self-updating chronometer**: `setChronometerCountDown(true)` + `base = endTime − now + elapsedRealtime()` for countdowns, up-mode for count-ups, frozen text when over (`d73.java:104-131` — `ye0`/`ff0`/`eo0` states). Style `DecoratedCustomViewStyle` (`defpackage/w63.java`). No auto-cancel flag for state notifications (`u63Var.c(8,false)` = clear FLAG_AUTO_CANCEL, `d73.java:67`).
- **Alert notifications** are built per type by `xe0.i(xj2, sm2)` (`defpackage/xe0.java:170-300`): title = "name, total-duration"; per-event-kind body and **action buttons** from enum `vl2` — Countdown finish → **{RESET, RESTART, SNOOZE}**, warning/pre-alert → **{CLOSE, RESET}**, CountUp/Interval notices → {CLOSE, RESET} (`xe0.java:189-208, 224-236`; enum `defpackage/vl2.java: START(0), RESTART(1), PAUSE(2), CONTINUE(3), RESET(4), LAP(5), INCREASE(6), CLOSE(8), SNOOZE(9)`).
- **In-app suppression:** alert notifications are skipped while MainActivity or MTSingleViewActivity is in the foreground (`defpackage/e63.java:132-136`: `if (oq1.C(context, MainActivity.class) || oq1.C(context, MTSingleViewActivity.class)) return;`).
- **Action execution** (`module/notice/NoticeReceiver.java:40-52` → `aa5`): actions run the same command pipeline as buttons (the `vl2` payload names the action; `w4oo` clears the NC state). **Snooze** = cancel current alerts (`x2.o` → `e63.a`) then schedule `ni2.ON_SNOOZE` at **now + 9 minutes** through the normal instrument-event scheduler (`defpackage/x2.java:163-176`).
- **Notification countdown ("NC")**: an ongoing "Status" notification per running timer, stepped by `vd6w` alarms (§2.3) and visually ticking via the RemoteViews chronometer between steps; master toggle `e4eh.sb4m` (default off — `k63.b()` reads `getBoolean("sb4m", false)`); per-id state in **`sy2f`** (`k63.e`, `defpackage/k63.java:80-118`; `h63.d(boolean)` toggle `defpackage/h63.java:105-121`).
- **Full-screen intent:** **declared but unused.** Permission `USE_FULL_SCREEN_INTENT` is in the manifest, and the `u63` wrapper supports `setFullScreenIntent` (`defpackage/t92.java:105` — NotificationCompat port), but **no app code ever sets `u63.h`/`m84.h`** (`xe0.i` explicitly sets `m84VarT.h = null` in every branch; `d73` never sets it). The "wake when locked" hint `m84.g` is set when `e4eh.h3dv` (default **true**) and the device is locked or the screen is off (`defpackage/x2.java:140-157`), but no consumer of `m84.g` exists in the posting pipeline (grep across all `m84` users). Related prefs `y7pr`/`m4ss` are written by a constructor (`defpackage/fb2.java:1210-1212`) but never read → **dead stores** (pointer note vs Part 3 §3.0, which guessed `m4ss` = deferred FSI).

## 5.0 Alert delivery at zero

Delivery chain (from Part 4): alarm → `InstrumentEventsScheduleReceiver` → `on1.c` → bus → `e63.b(xj2, sm2)` (`defpackage/e63.java:60-67`): guard `x2.q(sm2)` (does this instrument alert on this event) → `e63.e` (notification, §4.0) + `e63.d` (sound/vibration + repeats).

- **Playback dispatcher** `lp2.B(id, occurrence, rt2, timeout)` (`defpackage/lp2.java:224-266`): from alert config **`rt2`** {`n`: sound `mm2`, `o`: play duration, `p`: vibrate bool, `q`: repeat policy `p62`} builds a player list: sound → `new nl2(context, mm2, duration)`; vibration → `new cu2(context)`; both → composite **`o92`** (parallel players, `defpackage/o92.java`); stores per-id, marks id active, starts with auto-stop job `g72` (timeout or track duration).
- **Sound** `nl2` (`defpackage/nl2.java`): resolves the sound descriptor to a `Uri` and plays via **`MediaPlayer`**: `setDataSource(context, uri)`, `setAudioAttributes(usage per stream setting, CONTENT_TYPE_SONIFICATION)`, `prepareAsync`; **loops (`setLooping(true)`) when the requested play duration exceeds the track duration**, otherwise plays once; hard auto-stop after the duration (`nl2.java:112-152, 540-575`). If no duration given, duration = track duration.
- **Sound sources** (`xo2` implementors): built-ins **`nn2`**: `d1aw` = `res/raw/alarm_6s.mp3` "Alarm" (6 s) and `j8cr` = `res/raw/alarm_1s.mp3` "Short alarm" (1 s) via `android.resource://` URIs (`defpackage/nn2.java:23-27,34` — matches REFERENCE "2 default sounds" and Part 3 §4.0); custom imports: `pb2` = **file in app `cacheDir`** (SoundsActivity import copies picked audio to `File.createTempFile("sound", ext, getCacheDir())`, duration via `MediaMetadataRetriever` — `com/persapps/multitimer/use/ui/scene/sounds/SoundsActivity.java` → `defpackage/ec4.java:107-175`); `et2` = raw content-URI passthrough. **TTS**: `TextToSpeechActivity` pipeline synthesizes to a file (via `dq3`/`mo4`, `defpackage/mo4.java:36-71`) and wraps it as a `pb2` sound named `"<text>"` — TTS sounds are ordinary local files once created.
- **Vibration** `cu2` (`defpackage/cu2.java:107-157`): `VibrationEffect.createOneShot(500 ms, DEFAULT_AMPLITUDE)` **re-fired every 1 s** until stopped; usage tagged to match the audio stream (SDK ≥ 33 `VibrationAttributes` usage 17 ALARM / 19 MEDIA / 49 NOTIFICATION; older `AudioAttributes` usage 4/1/5).
- **Audio stream selection & DND** `r62` (`defpackage/r62.java`): user setting prefs **`h1th`** key `b4dg` (default 4): 3 → `USAGE_MEDIA`, 4 → `USAGE_ALARM`, else `USAGE_NOTIFICATION` (`r62.java:126-133`); requests audio focus (`fl`/`gl.b`); if DND is active and notification-policy access is granted (`ACCESS_NOTIFICATION_POLICY` in manifest), remembers the interruption filter, **turns DND off** and raises the alarm volume to the stored level (`th2m`) before playing, restoring everything at session end (`r62.java:135-165, 29-56`).
- **Repeat / alert-until-acknowledged** `e63.d` (`defpackage/e63.java:86-130`): repeat policy `p62` family — **`n62` "None"** (play once), **`o62(amount)` "Times"** — play now, then schedule up to `amount` repeats at **1-minute intervals** as `AlertRepeatReceiver` alarms (repeat index persisted per id in prefs **`rqx8`** — `"NC registry state"` log `e63.java:113`; each repeat re-enters `d` with `i>0` → play immediately, `e63.java:92-95`), **`m62` "Long"** — total alert span fixed at **5 minutes** (`rt2.a()`: `new ji2(5, TimeUnit.MINUTES)`, `defpackage/rt2.java:35-39`; `e63.java:101-105` plays with the 5-min timeout). Serialised policy ints: 0 = None, N = Times(N), 100 = Long (`defpackage/p62.java:7-18`).
- **Stop/acknowledge**: `e63.a(id)` cancels the notification, stops all players (`lp2.K`), and cancels every pending repeat alarm listed in `rqx8` (`defpackage/e63.java:42-58`). Any notification action (Close/Reset/Restart) also tears playback down via the `aa5`/command pipeline.
- **Alert config defaults**: `x2.g()` = default `rt2` = sound "Short alarm" (`nn2.f`), no vibrate, repeat None (`defpackage/x2.java:52-60`).

## 6.0 Sync / backup reality check

**Does the Android app sync anything anywhere? — No app-feature sync exists in v1.14.1. Local only, plus default Android Auto Backup.**

- **No app-code networking.** All `HttpURLConnection`/`OkHttpClient`/`Retrofit` users in `defpackage` are SDK islands: `r21`/`eg3`/`fn0`/`op5`/`m21`/`o90`/`ba0` (Google Play services / Firebase datatransport), `k21`/`tb` (AndroidX/work runtime), `r00` (download-listener plumbing), `z90`/`z60` (SQLBrite/Room runtime), `z60` db utils. No `api/`, `upload`, token, or user-data endpoint exists in app code (rg sweep, 2026-10-22).
- SDK-level traffic that does exist (documented Part 2): Firebase datatransport, Tenjin attribution (has its own Room `QueueEventDatabase` — install/attribution events, not timers), Play Billing. `INTERNET`/`ACCESS_NETWORK_STATE`/`ACCESS_ADSERVICES_*` permissions serve these.
- **The `zk6p.sqlite` "sync" outbox has no consumer.** Writers: `mo2.a/scope-count` (`INSERT INTO d3um {vp6u scope, g5ho key, sm0n value}` — `defpackage/mo2.java:584-594, 603-611`), `pq2` status updates on `ti9i` grouped by `j3az` (`defpackage/pq2.java:170-206`), `ct` grouped counts (`defpackage/ct.java:133`). **Nothing ever reads the queue to upload** — no network class references it. It is a vestigial or future-use outbox; the "Changes" `d3um` table functions as a local change-tracker (feeds incremental behavior of the diagnostics/export tooling, Part 3 §2.0/§4.0).
- **Android Auto Backup is ON with default rules**: `android:allowBackup="true"`, **no** `fullBackupContent`/`dataExtractionRules` attribute and no such files in `res/xml/` (listing: only widget info, billing phenotype, file_provider_paths, network_security_config (empty), locale config) — so timers DBs, history DBs, and all SharedPreferences are included in standard Google device backup/restore by the OS default rules. This is the only "backup" the Android app performs. (iOS iCloud sync is iOS-only; the Android app has no equivalent — consistent with `REFERENCE` sync guides describing cloud sync for iOS.)
- **Public intents API** (exported receiver `id.br_i9fa`, action **`com.multitimer.api`**): an automation entry point that maps intent extras to engine commands — `action` ∈ {`tap`, `run`, `start`[+`value` s], `pause`, `continue`, `reset`, `next`, `lap`, `add_time`[+`value`], `add_value`[+n], `get_value`}, filters `board`/`instrument`/`model`/`state` {inactive|running|waiting|completed} → executed through the same command pipeline as Buttons (`defpackage/hg.java:14-132`). **Pointer note for Part 4**: this is a second, external entry into the §4.0 command semantics — `FINDINGS/engine.md` §4 command tables apply unchanged; `FINDINGS/engine.md` not edited per plan §6.0.
- Widgets (`id.AppWidget_{m5rb,sz2x,u7lv}`, exported, standard `APPWIDGET_UPDATE`/`DELETED` filters; configure activities `use.appwidget.{mini1,mini2,single}`) — UI receivers, accounted for; detail deferred to Part 6 (UI).

## GAPS

- **G1 — `oq1.C(activity)` exact predicate**: used to suppress alert notifications while the app is foreground (`e63.java:132-136`); direction (skip when visible) is certain, but the exact check (resumed vs task-root) was not read.
- **G2 — `m84.g` (wake-when-locked hint)**: set under `e4eh.h3dv` (default true) but no consumer found in the notification path; possibly consumed by jadx-failed methods (60 classes, `WORK/JADX-FAILED-CLASSES.txt`) or truly vestigial with `y7pr`/`m4ss`. Smali check of `d73`/`aa5` would close it.
- **G3 — `lz3` descriptor store (`nz3` prefs) replay**: descriptors persist for cancel/cleanup, but boot re-arm goes through `on1`/`bj1l` only; whether any path replays `nz3` entries for non-instrument alarms (e.g. pending NC steps) after reboot was not fully traced (NC steps do re-arm via `k63.d()` — §3.0 — so impact is limited to hypothetical other users of `lz3`).
- **G4 — SDK ≥ 37 branch semantics**: `r62` gates the FGS on `Build.VERSION.SDK_INT >= 37` (Android 16+). Whether 37 is a real threshold or an R8-artifact of a version-range check was taken at face value (decompiled literal); behavior on 14/15 = no FGS needed for playback (documented as decoded).
- **G5 — `qu.N` diagnostics retention/cadence** (`c02u` config): local-only confirmed, exact upload-absence for the diagnostics bundle rests on the same no-network sweep as §6.0 (none), but the exporter's consumers (share sheet) are Part 6/7 material.

## CONFIDENCE

**High** for: service inventory + FGS type + the AFS-as-Android-16-host conclusion (readable service + `nj` wrappers + `r62` start path); the two-layer alarm strategy (`lz3`/`on1` fully read: per-instrument earliest-event alarm, exact/alarm-clock modes, Doze-proof flags, fallbacks); reboot path (`AppBootReceiver`/`AppBootJobService` fully read; `bj1l` + `k63.d()` rebuild); notification channels/poster/actions (`p10`/`d73`/`vn2`/`xe0`/`vl2` read); playback stack (`lp2`/`nl2`/`cu2`/`o92`/`rt2`/`p62` read: MediaPlayer, loop-on-long-duration, 500 ms vibration loop, None/Times/Long repeat policies, DND handling); sync reality (negative result from exhaustive rg sweep + manifest/res evidence).

**Medium** for: in-app suppression predicate details (G1), FGS threshold literal (G4), and the "no interrupted-alert replay" claim (absence-of-code argument over 6,460 defpackage files — every `mn1` bus consumer found was inspected, but R8 keeps residual risk).
