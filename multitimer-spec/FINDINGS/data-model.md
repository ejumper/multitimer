# FINDINGS — Data Model (Part 3)

Part 3 · 2026-10-22 · APK: `com.persapps.multitimer` v1.14.1 (282) (per `WORK/APK-INFO.md`)
Method: static analysis of `WORK/decompiled/jadx/sources/` (jadx tree), anchored on `WORK/MAP.md` §"Part 3 — data model". Obfuscated identifiers are quoted verbatim. Semantic names in **bold** are inferred from evidence (log strings, call sites, help docs); each such label carries its citation. All file paths relative to `WORK/decompiled/jadx/sources/`.

## 1.0 Entities

### 1.1 Storage overview — 3 SQLite databases (+ SharedPreferences, §3.0)

All DBs are created by one R8-merged `SQLiteOpenHelper`, `defpackage/mr2.java` (`switch (this.n)` dispatches three merged subclasses):

| DB file | Created at | Discriminator `n` | onCreate log |
| --- | --- | --- | --- |
| `desktop_debug_v25` | `defpackage/c02.java:856` — `new mr2(context, "desktop_debug_v25", null, 1, 1)` | 1 | tag `"iof8"`, `"DB create database"` (mr2.java:34) |
| `history_debug_v3` | `defpackage/lx3.java:380` — `new mr2(context, "history_debug_v3", null, 1, 2)` | 2 (default) | tag `"lfm0"`, `"HS create database"` (mr2.java:55) |
| `zk6p.sqlite` | `defpackage/oa2.java:816` — `new mr2(applicationContext, "zk6p.sqlite", null, 1, 0)` | 0 | (none) |

Schema DDL: `mr2.java:24-27` (case 0), `:36-50` (case 1), `:56-78` (default). Column names are runtime constants (`e4` wrapper objects, `.o` = literal string): `defpackage/vz3.java:57-69` (`_id`,`x3hw`,`o1ni`,`t6qk`,`hd8m`), `defpackage/uz3.java:78-100` (`_id`,`t6qk`,`w0jx`,`co4u`,`ho1g`,`b8rq`,`t5mh`,`ya1e`,`j6xo`), `defpackage/qu.java:60-73` (`md9i`,`jd1s`,`l8xg`).

**No migrations:** all three DBs are version 1; `mr2.onUpgrade` only logs, and private helper `b(...)` is an empty body (`mr2.java:83-97`). The `_v25`/`_v3` suffixes in DB *file names* suggest the developer carries schema generations in names, but no code path here opens an older-named DB (→ GAPS G1).

App does **not** use Room: the only `@Entity/@Dao/RoomDatabase` survivors are SDK classes (`defpackage/kb.java`; `com/tenjin/android/store/QueueEventDatabase_Impl.java`). Persistence = hand-rolled `SQLiteOpenHelper` (mr2) + SharedPreferences + `org.json`.

### 1.2 DB `desktop_debug_v25` — current workspace store

**Role (inferred, high confidence):** the live store for the workspace — boards/containers ("Node" documents), per-instrument run-state ("Session" documents), and the parent→child tree (membership table). Repo `c02(Context)` (`c02.java:855-857`, variant 29) behind transaction manager `dq3(Context)` (`dq3.java:30-41`: repo + Crashlytics-cache `yk` + lock `t92` + transaction cache `lp2` + notifier `mo2("dq3.Changes")` + DAO `vn2`) and composite DAO `fb2`/`km1`. The app's "Cancel last changes" undo runs as a DB transaction on this store (`defpackage/fw3.java:48-58` — `ai0` description `"Cancel last changes"`).

Rows follow one pattern: `_id TEXT PRIMARY KEY` = **document path id whose last segment is the type id** (`fo2.a(id)` extracts it — `c02.java:70`; `mi2.a = tf4.O0(id, "/")` = parent path — `c02.java:91`), an `INT8` **last-modified epoch-millis** (writes use `System.currentTimeMillis()` — `defpackage/ik2.java:165,185`), and a `TEXT` **JSON payload** (`new JSONObject(string)` — `c02.java:69`).

#### Table `hf5k` — **Node** documents (boards/containers/instruments)
- `_id TEXT PRIMARY KEY` (vz3.u)
- `t6qk INT8` — last-modified epoch millis
- `hd8m TEXT` — JSON payload (§1.6)
- DDL `mr2.java:36-39`; row class `ci0 {String a; long b; e4 c}` (`defpackage/ci0.java:9-16`); ContentValues `vz3.java:708-715`; Cursor `vz3.java:607-614`; table switch `vz3.java:628`; binding `ci0→vz3.t` in `c02.p(Class)` (`c02.java:173-183`). Upsert = `insertWithOnConflict(..., 5)` (REPLACE) — `c02.F` (`c02.java:289-292`).

#### Table `t3bh` — **Session** documents (per-instrument run state)
- `_id TEXT PRIMARY KEY` (uz3.p)
- `t6qk INT8` — last-modified epoch millis
- `w0jx TEXT` — JSON payload
- DDL `mr2.java:43-46`; row class `sh0 {String a; long b; String c}` (`defpackage/sh0.java:9-15`); mapping `uz3.java:331-340` + `uz3.java:210-218`; table `uz3.java:260`; binding `sh0→uz3.o` (`c02.p`).

#### Table `mq3x` — **membership** edges (parent → children)
- `md9i TEXT` (qu.s) — parent document id
- `jd1s TEXT` (qu.t) — child document id
- `INDEX l8xg ON mq3x (md9i)` (qu.u) — parent lookup
- DDL `mr2.java:48-50`. No PK. Semantics: set-diff sync of a parent's children — `c02.G(parentId, childIds, onAdded, onRemoved)` reads existing `WHERE md9i = ?`, deletes removed `WHERE jd1s = ? AND md9i = ?`, inserts new (`c02.java:299-380`); reverse lookup (which parent holds a child) `vn2.java:1103`, `fb2.java:341`; delete-by-parent `c02.c` (`c02.java:419`).

### 1.3 DB `history_debug_v3` — document store for Node/Session/Details families

**Role (inferred, high confidence):** companion document store; logs name the three row families **"Node"**, **"Session"**, **"Details"** (`c02.java:443-451`: `"DB fetch(Node)"` etc.). Repo `lx3(Context)` (`lx3.java:379-383`); composite `eq3(Context)` (`eq3.java:550-557`: `o`=lx3, `p`=lock `t92`, `q`=cache `c02(24)`→`km1(14)`, `s`=notifier `mo2("eq3.Changes")`); write path `hf1.f(gj2)` (`hf1.java:131-188`, log `"DB update(id)"`); fetch `c02.e` / `hf1.b`; read-single `lx3.r`; delete `c02.b` case 12 (reads row, caches snapshot in `km1`, then deletes — tombstone pattern, `c02.java:341-372`).

#### Table `y9er` — **Node** documents (same shape as `hf5k`)
- `_id TEXT PRIMARY KEY` (uz3.u), `co4u INT8` (last-modified), `ho1g TEXT` (JSON payload) — DDL `mr2.java:56-60`
- row class `r53` (`defpackage/r53.java:9-30`); mapping `uz3.k` case 1 (`uz3.java:299-311`); Cursor `uz3.java:219-226`; table `uz3.java:262`; binding `r53→uz3.t` (`lx3.java:71-73`).

#### Table `r6vk` — **Session** documents (extended)
- `_id TEXT PRIMARY KEY` (uz3.z), `b8rq INT8` (last-modified), `t5mh TEXT` (JSON payload), `ya1e TEXT` (**denormalized parent Node id** — stores `lj2.d`), `j6xo INT8` (**event timestamp as long** — stores `lh2.e`, read back `new lh2(cursor.getLong(4))` `uz3.java:247`; `lh2` wraps a java.time value, cf. `DateTimeFormatter lh2.o` `lj2.java:38-40`)
- DDL `mr2.java:62-71`; row class `i54 {a,b,c,d:String,e:lh2}` (`defpackage/i54.java:9-27`); mapping `uz3.k` default (`uz3.java:312-326`); Cursor `uz3.java:227-248`; table `uz3.java:264`; binding `i54→uz3.y` (`lx3.java:74-76`).

#### Table `ed1j` — **Details** documents
- `_id TEXT PRIMARY KEY` (vz3.p), `x3hw INT8` (last-modified), `o1ni TEXT` (JSON payload) — DDL `mr2.java:73-77`
- row class `up0` (`defpackage/up0.java:9-30`); mapping `vz3.k` (`vz3.java:675-685`); Cursor `vz3.java:595-605`; table `vz3.java:626`; binding `up0→vz3.o` (`lx3.java:77-79`). Details exist only in this DB (no main-DB counterpart — `c02.p` knows only Node/Session).

Class ↔ table map (also `defpackage/hf1.java:100-112` fetch path): main→history mapping `c02.k(Class)` (`c02.java:166-176`): `fj2→r53` (**Node**), `lj2→i54` (**Session**), `cj2→up0` (**Details**).

### 1.4 DB `zk6p.sqlite` — change outbox / sync queue

#### Table `d3um` — scoped key/int state
- `vp6u TEXT NOT NULL` — scope/owner (constant per writer; bound as `this.p` — `mo2.java:603,695,773,846,896`)
- `g5ho TEXT NOT NULL` — item key
- `sm0n INTEGER NOT NULL` — int value
- `PRIMARY KEY (vp6u, g5ho)` — DDL `mr2.java:25-28`
- Ops: REPLACE-insert, count-per-scope, value by (scope,key), all (key,value) per scope, keys per scope, delete pair (`mo2.java:587-937`). Writers: `mo2` "Changes" instances (`eq3.java:556` `"<Class>.Changes"`, `dq3.java:38`), fed after main-DB commit (`dq3.f` → `((mo2) this.s).H(...)` `dq3.java:160`). **Change-log/outbox metadata** (inferred).

#### Table `ti9i` — sync queue rows
- `vp6u TEXT NOT NULL` (scope), `me1d TEXT NOT NULL` (**queue/consumer name**), `glb8 TEXT NOT NULL` (**entry id**), `j3az INTEGER NOT NULL` (**status** — grouped/counted `GROUP BY j3az` `ct.java:133`; in-place updates `tv5.java:91`, `pq2.java:170,206`), `a6rm INTEGER` nullable (secondary timestamp), `rf4v TEXT NOT NULL` (payload 1), `aj3d TEXT NOT NULL` (payload 2), `j1ag INTEGER NOT NULL` (timestamp; rows read `ORDER BY rowid ASC` `tv5.java:189`)
- `PRIMARY KEY (vp6u, me1d, glb8)`; `INDEX idx_sync_queue_status ON ti9i (vp6u, me1d, j3az)` — DDL `mr2.java:26-28`. The readable index name is the only unobfuscated schema identifier in the app → queue semantics certain.
- Users: `tv5.java` (insert/update/query/delete), `qd.java:531,556` (enqueue), `lr2.java:137` (delete), `pq2.java` (status transitions), `ct.java` (status counts).

### 1.5 Relationships

- Document ids are paths; the last segment is the document type id (`c02.E()` dispatch — `c02.java:67-135`).
- Node→children: `mq3x` edges (`c02.G`).
- Session→Node: `r6vk.ya1e` column **and** payload key `edj3` both carry the parent id (`uz3.k` default stores `lj2Var.d`).
- Details→Session: Details doc `_id` = the event id (`cj2.a = e62Var.a` — `h.java:681-684`); payload `hy1a` = detail list.

### 1.6 JSON payload schemas (inside TEXT columns)

Payloads are JSON objects (`new JSONObject(payload)` — `c02.E` `c02.java:69`), keys obfuscated. Type id ↔ class ↔ keys (`c02.E` `c02.java:67-135`; serializers `mi2.b(jh2)` implementations; the app-model→document bridge `h.java` case 28, `h.java:543-700`):

| Type id | Class | Stored in | Payload keys → meaning |
| --- | --- | --- | --- |
| `f6im` | `fj2` **Node** | `hf5k`, `y9er` | `ra4f`→**name** (`dk2.getName()` `h.java:572`); `xeo9`→nested object **j92** (`h.java:576`; `j92` = color — `qj2 icon`, `j92.a` int color `c6.java:106-108`); `me9r`→**icon name** (`icon.getName()` `h.java:581`); `k5kp`→**instrument type** (`oj2` enum name — TIME/POMODORO/STOPWATCH/AMOUNT, `h.java:553-567`); `w7no`→**app-side type id** (`h.java:585`) |
| `i8nq` | `kj2` **Session** | `r6vk` | `crk6`→**ji2 value**; `z7tz`→**boolean** (`c02.java:96-109`; built from app event `xm2` `h.java:645-660`) |
| `pg1k` | `nj2` **Session** | `r6vk` | `crk6`, `z7tz` (same shape; from event `ot2` `h.java:630-644`) |
| `l30j` | `aj2` **Session** | `r6vk` | `da3x`→**int** (`c02.java:111-116`; from event `s62` `h.java:671-680`) |
| `x8rd` | `ij2` **Session** | `r6vk` | `h3ca`→**list** (`c02.java:133-138`; from event `aq2` `h.java:661-670`) |
| `p5kw` | `cj2` **Details** | `ed1j` | `hy1a`→**list of detail items** (element serializer `dj2.e`; items carry `.b` = `lh2` timestamp — `h.java:690-698`) |

Session document common fields (serialized by `lj2.b` — `lj2.java:60-68`): `edj3`→**parent Node id**, `xg9x`→**timestamp (lh2)**, `dg5h`→**timestamp (lh2)**, `d2eo`→**string**. Base fields `mi2.a` (id) and `mi2.b` (last-modified long) are **not** in the payload — they are the row's `_id`/`t6qk` columns (`hf1.f`: `mi2Var.b = System.currentTimeMillis()` then `mi2Var.b(g03Var)` writes only subclass keys — `hf1.java:133-147`).

Instrument classes → `oj2` type (`h.java:549-567`): `ka2`, `xn2`, `sk2`, `hb2`→TIME; `cn2`→POMODORO; `np2`→STOPWATCH; `ta2`→AMOUNT. The 7 instrument-type ids observed by the change observer `d72`: `"g5vs","y9wg","ok9y","hz3x","s5lu","m6zp","e2kh"` (`d72.java:11`); original model class name `com.persapps.multitimer.model.instrument.MTInstrument` preserved in signature string `d72.java:33`. Evidence tying type ids to timer kinds: `w6.java` case 9 — unnamed `ka2` falls back to display name `"g5vs"`; case 10 — unnamed `hb2` → `"s5lu"` (i.e., `g5vs`=ka2 kind, `s5lu`=hb2 kind, each a distinct timer type).

### 1.7 Non-DB entities (files, live queries)

- **Default sounds:** `res/raw/alarm_1s.mp3`, `res/raw/alarm_6s.mp3` (`WORK/MAP.md` §2.3; matches help doc "There are 2 sounds in the library by default" — `REFERENCE/how-tos-for-android-how-to-add-custom-sounds.md`).
- **Custom sounds:** no dedicated storage found. Add-flows are `cc4.RINGTONE` (system ringtone picker) and `cc4.DOCUMENT` (SAF document) — `defpackage/cc4.java:13-16`; titles resolved live from `RingtoneManager` (`ec4.java:54-56`). No `takePersistableUriPermission` anywhere in the tree (searched). → GAPS G6.
- **Diagnostics:** `logs.zip` written to `filesDir` and shared (`b52.java:141-177` builds it by zipping a file list — `hh0` case 7 `ZipOutputStream`). Not user data.
- **Crashlytics settings cache:** `filesDir/fu4j` (`defpackage/yk.java:12-14`) — SDK plumbing, not app data.

## 2.0 Storage & migrations

1. **Migrations: none.** All DBs version 1; `onUpgrade` is a logging no-op (`mr2.java:83-97`). Migration history = empty (checklist item satisfied by absence; nothing to version-order).
2. **Transactions:** main-DB writes run inside explicit transactions managed by `dq3` (`beginTransaction` in `dq3.h` `dq3.java:167-169`; `setTransactionSuccessful`/`endTransaction` in `dq3.f` `dq3.java:83-169`), with a three-map row cache (`km1` maps inside `lp2`) committed/rolled back with them; after commit, changes are pushed to the `zk6p.sqlite` outbox and a change list is logged (`"DB changes: "` `dq3.java:158`).
3. **Caching:** reads are served through per-family row caches (`km1` old-row/new-row maps — `c02.b` case 12, `hf1.f`).
4. **Undo:** "Cancel last changes" = a compensating DB transaction on `desktop_debug_v25` (`fw3.e` `fw3.java:48-58`); free tier limited to 3 undos via counter `lu2l.r0hr` (§3.0), unlimited for Pro (`gj.a(context)` check — `fw3.java:20-24`).
5. **Sync storage:** `zk6p.sqlite` (outbox) + `history_debug_v3` (document replication store) constitute the sync engine's storage; the engine itself is Part 5/7 material. The deferred decision in `PLAN/PHASE1/OVERVIEW.md` §2.0 (sync *design*) is respected here — this section documents storage only.
6. **SDK databases present but out of app scope:** Tenjin `QueueEventDatabase` (`com/tenjin/android/store/QueueEventDatabase_Impl.java`), Firebase transport (`sz3`), Google Play services internals.

## 3.0 Preferences

Named SharedPreferences stores (all `MODE_PRIVATE`). "Meaning" is from the UI widget that reads/writes the key (layout id / activity) or the code path, cited per key. `**(PRO)**` where pro-gating applies.

| Store | Key | Type | Default | Meaning (evidence) |
| --- | --- | --- | --- | --- |
| `ei4h` (app settings) | `w8an` | bool | false | **Wait animation disabled** — inverse of `wait_animation_switch` (`ExtraSettingsActivity.java:26-31`, writer `a7.java:40-46` `putBoolean("w8an", !z)`) |
| `ei4h` | `y5gz` | bool | true | **Double-tap to start/stop** (`double_tap_switch`, `ControlsSettingsActivity.java:32-33`; consumed in instrument views `ae2.java:158-166`, `jf2.java:99-107` gating `aa5.m(instrument)`) |
| `ei4h` | `i9in` | bool | false | **Ask name for quick timer** (`quick_timer_name_switch`, `ControlsSettingsActivity.java:69-74`) |
| `uka9` (alert settings, via `lz3.f`) | `ozi7` | bool | false | **Alarm channel mode** — `clock_alarm_disabled_switch` (`AlertSettingsActivity.java:83-86`); runtime effect: true → `AlarmManager.EXACT_AND_ALLOW_WHILE_IDLE`, false → `ALARM_CLOCK` (`qu.java:380`, `lz3.java:99`) |
| `e4eh` (notice settings, via `h63.b()`) | `sb4m` | bool | false | **Notice (persistent alert) state** — `notice_state_switch` (`AlertSettingsActivity.java:76`); toggling starts/stops keeper `k63` (`h63.java:100-117`) |
| `e4eh` | `h3dv` | bool | true | **Full-screen notice** — `full_screen_notice_switch` (`AlertSettingsActivity.java:79`; consumed `x2.java:147`) |
| `nz67` (onboarding) | `st7r` | bool | false | **Welcome screen shown** — set true at end of `WelcomeActivity` (`WelcomeActivity.java:111-116`); gates re-showing in `MainActivity.G()` on first launch only (`MainActivity.java:134-142`) |
| `n8fb` | `i5vm` | bool | false | **Premium banner dismissed** — hides a view styled `R.attr.app_contentPremium` (`qk2.java:1043-1049`; writer `h.java:137-143`) |
| `h1tf` | `t2iz` | String (JSON) | null | **Notification-channel records** — JSON array of `q10{z8qi: channel id, nao9: name, h52t: sound Uri}` (writer `vn2.java:572-590`, reader/eraser `o10.java:36-105`; serializer `vz3.java:717-724`) |
| `lu6b` (appearance) | `nz0j` | String (enum `ip4`) | null→SYSTEM | **App theme** (`ot5.V` `ot5.java:375-386`; writer `g64.java:55-62`; shown as `theme_value` `h64.java:61-75`) |
| `lu2l` (workspace) | `y6nz` | String | null | **Current board id** (`ch0.a/b` `ch0.java:13-58`; notifies `setBoard` listeners) |
| `lu2l` | `r0hr` | int | 0 | **Undo operations used** (free tier): allowed = `3 − r0hr`, 0 → Pro dialog; incremented per undo (`fw3.java:17-58`) **(PRO)** |
| `h1th` (audio) | `b4dg` | int | 4 | **Notice stream type** (3=_music_?, 4, 5 selectable — `AlertSettingsActivity.P={4,5,3}` `AlertSettingsActivity.java:26`; read `r62.c` `r62.java:103-105`) |
| `h1th` | `th2m` | int | none (`contains` check) | **Notice volume override** (`r62.b` returns null = use system volume — `r62.java:96-102`) |
| `q3bu` (version stats, `pq1.O/P`) | `mh7z` / `e3yf` | String / long | "" / 0 | Current **versionName / versionCode** (`pq1.java:353-367`) |
| `q3bu` | `kw3s` / `h5sr` | String / long | "" / 0 | Previous **versionName / versionCode** (roll-over on update — `pq1.java:382-392`) |
| `q3bu` | `ax4g` / `ml7x` | long / long | 0 / 0 | **Total launch count / launches of current version** (incremented at every app start `pq1.java:394-400`; `e==1` gates welcome screen `MainActivity.java:133`) |
| `q7tv` (TTS) | `n4me` | String | null | **TTS voice name** (`wo4.java:34-46`, `k24.java:152-160`) |
| `q7tv` | `r8te` | float | 1.0 | **TTS speech rate** (`wo4.java:38`, `k24.java:170-177`) |
| `q7tv` | `p6ch` | float | 1.0 | **TTS pitch** (`wo4.java:40`, `k24.java:181-188`) |
| `uv5y` (history) | `nba2` | String | null→default | **Keep history records** — encoded `"<kind>:<count>"`: `jaq2`=default(forever), `e6zq:<years>`=YEARS, `qys9:<days>`=DAYS (`mf5.J/W` `mf5.java:205-223,590-615`; shown as `keep_records_value` `HistorySettingsActivity.java:25`; classes `xf1`=YEARS, `vf1`=DAYS) |
| `j5gf` (maintenance) | `hc4p` | long | 0 | **Last daily-job run** (epoch); if ≥1 day ago, background job `t0(...,23)` runs (`ag1.java:20-31`) |
| `da1p` (maintenance) | `op2t` | long | 0 | **Last daily-job run** for `aa5` executor — ≥1 day gate then job `"a75i"` (`aa5.java:141-169`) |
| `o3pa` (colors) | `vh6r` | String (CSV ints) | null | **Custom color palette** — user colors as comma-joined ints (`c6.java:97-103` writes; `l92.b` reads `l92.java:38-46`) |
| `mk4n` (pro-gating) | `bnf2` | StringSet | null | **Free-tier allowed document-type prefixes** (set of `tf4.O0(path,"/")` type ids; checked before allowing creation `aq1.java:25-36`, populated `bu.java:203-217`) **(PRO)** |
| `gx8b` (picker) | `y5ty` | bool | false | **Time-picker 1-minute step** (vs 5) (`qk0.java:100-115,141-148`) |
| `jy6a` (widgets) | `w<appWidgetId>` | String (JSON) | none | **Per-widget config** — `{f0gd: bound board/instrument id, u1bg: widget-type enum `z65`, mn9f: bool}` (`e75.b/d` `e75.java:44-70,72-96`; cleanup `e75.c`) |
| `l4kt` (analytics) | `c5tr` | String (UUID) | generated | **Install/client UUID** for telemetry requests (`v50.r` `v50.java:935-950`) |
| `z6hs` (LEGACY) | (any) | String (JSON) | — | **Legacy scheduled-events store** — all entries copied to `bj1l` and pending alarms cancelled at startup (`ly4.java:70-90`); values `{bvp5: [um2…]}` (`um2` = scheduled event: `.e`=event id, kind `.a`, target `.b`, …) |
| `bj1l` (events) | (instrument/event id) | String (JSON) | — | **Scheduled events store** — values `{bvp5: [um2…]}` (writer path `ly4.java:76-82`; reader `on1.b` lists keys `on1.java:31-39`, `"EV receive event"` `on1.java:48-52`; accessed via `km1(25)`→`w6(20)` `km1.java:91-93, w6.java:105`) |
| `rqx8` (events) | (instrument id) | String (JSON) | — | **Event records by instrument** — values `{nr4e: [jm2…]}`, `jm2.a` = timestamp (`x6.d` `x6.java:66-73`; lookup-before/after `x6.a/b` `x6.java:29-46`) |
| `sy2f` (events, `x6` variant 1 / `k63`) | (instrument id) | int or String (JSON) | — | **Countdown-notice state**: int = number of scheduled countdown steps (`e63.a/d` `e63.java:22-40,120-140` `"NC registry state"`); plus same `{nr4e:[jm2]}` records via `x6(context,1)` (`x6.java:12-15`, `ik2.java:215`) |
| `u2j3` (`nz3` case 1, owner `o55`) | (dynamic) | String (JSON `q55`) | — | Generic **JSON-per-key records**: `{v6h4: bool, tw6b: str, ld4f: str, tx1m: long→zt2, xh9a: list, or0u: bool}` (`nz3.a/b` `nz3.java:23-42,44-66`) |
| `zj0o` (`nz3` case 0, owner `lz3`) | `"intent(<filterHashCode>)"` | String (JSON `q55`) | — | **Scheduled-alarm records** for the exact-alarm scheduler; removed on cancel (`lz3.a` `lz3.java:36-45`) |
| `y7pr` (billing) | (product id) | String (enum `lb1` name) | null | **Play-billing product state** (`"GP setProductState(<id>, <state>)"` — `fb2.java:585-615`) **(PRO)** |
| `m4ss` (billing) | (product id) | (marker) | — | **Missing-product markers** (cleared when product reappears — `"GP clearMissingProductTime"` `fb2.java:1117-1127`) **(PRO)** |
| `uc1y` | — | — | — | Store **created** in `mo2(MainActivity)` (`mo2.java:1112-1115`, constructed `fv3.java:19`) but **no key reads/writes found** in `mo2` (all `this.p` uses cast to other types) → appears unused (→ GAPS G7) |
| `us5k` | — | — | — | Store **created** in `km1` case 22 (`km1.java:87-89`) but no `km1(context,22)` construction found → unused |

**SDK-owned stores (present, excluded from app model):** `app_set_id_storage` (`app_set_id`, `app_set_id_creation_time`, `app_set_id_last_used_time` — Play core, `sk5.java:245-251`, `l9.java:628`), `install_referrer_tracker` (`referrer_reported` — `dn1.java:22,1100-1104`), `com.google.android.gms.measurement.prefs`, `google.analytics.deferred.deeplink.prefs`, `com.google.firebase.crashlytics`, `com.google.android.gms.signin`, Tenjin `INSTALL_PREFERENCE`.

**Key count (checklist):** 30 named keys across 21 app stores (rows above, excluding the two unused/empty stores and dynamic-key stores); plus 8 dynamic-key stores (`bj1l`, `rqx8`, `sy2f`, `u2j3`, `zj0o`, `y7pr`, `m4ss`, `jy6a`) + legacy `z6hs`. Every store discovered by the `getSharedPreferences` sweep appears above, classified app/SDK/unused.

## 4.0 Serialization / backup formats

### 4.1 Boards export/import — `.mtb` file (MIME `application/multitimer`)

- **File = a single UTF-8 XML text document.** Export flow: UI creates a `CREATE_DOCUMENT` intent titled `"MultiTimer - boards.mtb"` (or `"MultiTimer - <name>.mtb"`) with type `application/multitimer` (`hh0.java:172-186`); the picked stream receives one `String` written as UTF-8 (`r00.java:261-306` — `bufferedWriter.write(na5Var.a)`). `na5.a` is the XML text produced by an `XmlSerializer` into a `StringWriter` (`uz3.java:688-691`). Payload holder `na5 {a: xml, b: suggested name}` (`defpackage/na5.java`, built `uz3.java:700-718`).
- Note: the `.mtb` extension appears only in the title string; the MIME type is the machine-readable contract. (Do **not** confuse with `logs.zip`, a diagnostics ZIP — `b52.java:141-177`.)
- **XML envelope** (writer `nb.java` default case, `nb.java:176-199`):

```xml
<?xml version="1.0" encoding="utf-8"?>   <!-- startDocument("utf-8", FALSE) -->
<Root class="MTB">
  <Version>1</Version>
  <Date>2026-10-22 ...</Date>            <!-- ua5.c date format -->
  <Board class="Board"> ... </Board>     <!-- one per exported board -->
</Root>
```

- **Board element** (`sp0.java` case 20, `sp0.java:995-1026`): attributes/class `Board`; children: `<Key>` = **remapped id** (internal document ids are aliased to `k1`, `k2`, … by `la5.x` — `la5.java:22-37`), `<Name>`, optional `<Matrix>` containing `AdaptiveMatrix` or a flexible-matrix element (`qi2` via adapter `ow5.d`), then one `<Timer>` child per instrument (each serialized with its own class attribute).
- **Element vocabulary** (start tags + `class` attributes + child tags harvested from the export adapters `oa2`, `da2`, `kb5`, `lv4`, `sp0`; all human-readable, not obfuscated):
  - Instrument classes: `CountdownTimer`, `CountupTimer`, `PomodoroTimer`, `Counter`, `QuickTimer`, `Container`, `Board`
  - Structure/properties: `Timer`, `Item`, `Button`, `Buttons`, `Command`, `Action`, `Icon`, `Color`, `Time`, `Clock`, `Alert`, `StartAlert`, `FinishAlert`, `BreakAlert`, `WorkAlert`, `WorkTime`, `BreakTime`, `LongBreakTime`, `Repeats`, `Notice`, `Mode`, `Matrix`, `AdaptiveMatrix`, `FlexibleMatrix`, `Format`, `Condition`, `FinalValue`, `StartValue`, `StepValue`
  - Condition values include plain text (e.g. `completed` — `sp0.java:985-993`)
- Example adapters (shape evidence): `CountdownTimer` writes `Color`, `Icon`, `Time`, `Alert`, `Clock` (`oa2.java:1004-1013`); `Counter` writes `Color`, `Icon` (`oa2.java:1020-1024`); interval-family writes `Time`, `Color`, `StartAlert`, `FinishAlert` + `Item` children (`kb5.java:2278-2293`); alert sub-element carries `StartAlert`/`FinishAlert`/`Alert` alternatives (`kb5.java:2140-2147`).
- **Import:** the reader parses the same tags into model objects (`sa5.a("Board")` … — `sp0.java:534-536`, `vp3.java:214`). Cross-platform: file produced on iOS imports on Android and vice-versa (help doc — `REFERENCE/multitimer-android-app-features.md:420-433`, `REFERENCE/how-tos-for-android-how-to-import-an-export-file-into-the-multitimer-application.md`).
- Id remapping (`la5`) means exported ids (`k1`…) are local to the file; on import new internal ids are minted.

### 4.2 Timer history export — CSV (per-timer files)

- `pq1.L(context, list)` writes one CSV file per timer into `cacheDir`, filename = sanitized timer name (`[^\\p{L}\\p{N}]+`→space, `\\s+`→space, truncated to 50 chars, + `.csv`; fallback name `"MultiTimer"`), then shares all via `ACTION_SEND_MULTIPLE`, type `application/csv`, through FileProvider authority `<pkg>.ga2u` (`pq1.java:239-300`).
- CSV content = the history grid rendered as text: header row + one line per entry, cells joined with `,`, string cells quoted (`km1.toString()` case 7 — `km1.java:1230-1245`; quoting mapper `vf.java:52-55`). Rows come from the history view-model of the selected timer (`eq3.java:259` — `new xy("<name> - <suffix>", km1Var.toString())`).
- Help doc ground truth: history is written only after a timer is stopped; export produces a CSV openable in any editor (`REFERENCE/how-tos-for-ios-how-to-export-timer-operation-data.md`, `REFERENCE/multitimer-android-app-features.md:54,196`).

### 4.3 Other formats

- **Scheduled events (internal):** JSON in prefs (`{bvp5:[um2…]}` in `bj1l`/`z6hs`; `{nr4e:[jm2…]}` in `rqx8`/`sy2f`) — §3.0.
- **Widget config (internal):** JSON in `jy6a` — §3.0.
- No JSON settings export, no Room backup, no auto-backup rules beyond defaults (`res/xml/` holds only widget infos, `file_provider_paths`, `network_security_config` — `WORK/MAP.md` §2.3).

## 5.0 Cross-check: REFERENCE features ↔ data model

Compared against `REFERENCE/index.md` inventory, principally `REFERENCE/multitimer-android-app-features.md` and `REFERENCE/timing-tools.md`:

| REFERENCE feature | Backing store | Status |
| --- | --- | --- |
| Boards, rearrange boards | `hf5k` Node docs; board order via workspace (board id in `lu2l.y6nz`) | ✅ consistent |
| Timers (Countdown/Count-up/Stopwatch/Pomodoro/Interval/Stepped/Amount/Quick) | Node docs (`oj2` types TIME/POMODORO/STOPWATCH/AMOUNT; 7 type ids `d72.java:11`) | ✅; exact mapping of the 7 ids to the 8 doc/tool kinds → GAPS G4 |
| Container | Node docs + `mq3x` membership; export class `Container` | ✅ |
| Buttons (replaces "Commands") | export elements `Buttons`/`Button`/`Command`/`Action` | ✅ (internal storage = Node/Session docs; see GAPS G5) |
| History (per-timer log) | Session/Details docs in `history_debug_v3` (+`t3bh` current state) | ✅ |
| History CSV export | §4.2 | ✅ |
| Boards export/import (Android↔iOS) | §4.1 | ✅ |
| Sounds (2 default + custom) | `res/raw` + live `RingtoneManager`/SAF docs; per-timer `Alert` elements | ⚠️ custom-sound library persistence not found (GAPS G6) |
| Text-to-Speech | `q7tv` prefs | ✅ |
| App widgets (mini1/mini2/single/quick) | `jy6a` per-widget JSON + `res/xml/app_widget_*_info.xml` | ✅ |
| Pro licensing / subscriptions | `y7pr`/`m4ss` product states; `mk4n.bnf2` free-type whitelist; undo limit `lu2l.r0hr` **(PRO)** | ✅ (gating logic = Part 7) |
| Notifications & alerts troubleshooting (alarms, DND) | `zj0o` alarm records, `h1th` stream/DND, `sy2f` countdown state, `h1tf` channel records | ✅ |
| Template gallery | — | ❌ no backing store found — templates are presumably server-fetched and imported as boards (GAPS G8) |
| URL scheme / API for Android | — | Not a persistent-data concern; runtime dispatch (Part 6/7 scope) — noted, no discrepancy |
| Localization (user-contributed) | resource-level; no data-model impact | ✅ n/a |

**Discrepancies found (docs vs binary):** none contradicting. Two doc claims *confirmed* by code: "There are 2 sounds in the library by default" (`res/raw` count) and "history only after timer stopped" (Session/Details docs written on stop/complete events via `h.java` case 28).

## GAPS

- **G1 — DB naming/versioning:** the semantic split between `desktop_debug_v25` (current state) and `history_debug_v3` (document/replication store) is inferred from call-graph roles, log strings (`"DB fetch(...)"`, `"DB update(...)"`, `"HS ..."`), and consumers (History screen reads `eq3`/`lx3`). The *names* strongly suggest the "history" DB is the sync replication store, but no string in the binary states it outright. No older-version DB files are referenced (migration-by-rename hypothesis unverified).
- **G2 — Full per-field export schema:** the `.mtb` XML envelope + full element vocabulary + 3 example adapters are documented (§4.1); a field-by-field expansion for all 6+ instrument classes was not enumerated one-by-one (traceable from the cited adapters `oa2`/`da2`/`kb5`/`lv4`/`sp0` if Part 8 needs it).
- **G3 — Nested payload object `j92`/`ji2`/`dj2`/`so3` internals:** keys for these nested JSON objects (color object inside Node `xeo9`; `ji2` in Session `crk6`; detail items `dj2`) are not yet itemized (serializers: `j92.c` default at `fj2.b` `fj2.java:20`, `da2.e` list, etc.).
- **G4 — Instrument type-id ↔ timer-kind table:** 7 ids (`g5vs`,`y9wg`,`ok9y`,`hz3x`,`s5lu`,`m6zp`,`e2kh`) ↔ 4 `oj2` enums + app classes (`ka2`,`xn2`,`sk2`,`hb2`,`cn2`,`np2`,`ta2`) only partially pinned (only `g5vs`→ka2-family, `s5lu`→hb2-family evidenced, `w6.java` cases 9-10). Full table = one focused session in `defpackage` around `oj2`/`d72` consumers.
- **G5 — Buttons/Commands internal storage:** export classes exist, but whether Buttons are Node documents (and of which type id) was not traced.
- **G6 — Custom-sound library list:** no dedicated persistence found; sounds are picked per-timer into `Alert` elements (`RINGTONE` uri or `DOCUMENT` uri). If a "library" list exists, its store was not identified (searched: prefs sweep, DB tables, file stores).
- **G7 — `uc1y`/`us5k` stores:** created but no usage found; possibly dead code in this build (R8 merge remnants).
- **G8 — Template gallery storage:** no local store identified; likely network-fetched (consistent with INTERNET permission + okhttp presence) — deferred to Part 6/7 recon.
- **G9 — `zk6p.sqlite` scope semantics:** `vp6u` scope value(s) used by `mo2` writers and `ti9i` queue consumer names (`me1d`) were not enumerated to literal strings (they are runtime constants; a 30-minute trace in `mo2`/`qd` constructors would pin them). Sync queue *processing* is Part 5 scope.

## CONFIDENCE

**High** for: the 3-DB inventory, every CREATE TABLE (verbatim from `mr2.java`), all column types/PKs/indexes, entity↔table bindings, the JSON-payload mechanism, the `.mtb` XML envelope + element vocabulary, the CSV export mechanism, and the preference key inventory (each key has a read/write citation). 

**Medium** for: semantic labels of tables ("Node"/"Session"/"Details" roles, store purposes) — every label has cited evidence (log strings or UI wiring) but the labels are inferences over obfuscated names; the app↔history DB role split (G1); instrument type-id mapping (G4).

**Low** for: none of the load-bearing claims; only the noted GAPS are unresolved, and each is flagged with what was tried.
