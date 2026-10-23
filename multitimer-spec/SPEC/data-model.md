# SPEC — Data model

Condensed from `FINDINGS/data-model.md` (deep reference with raw citations). The app is **local-only**: 3 SQLite databases + SharedPreferences + JSON documents. No migrations exist anywhere (all DBs version 1; upgrade path is a logging no-op). No Room, no content providers, no cloud storage — Android's default Auto Backup (`allowBackup="true"`, no exclusion rules) is the only backup.

## 1. Entities

The app is document-oriented. Every persistent object is a **document**: a path-style id (`"<parent>/<typeid>"` — last segment = type id), a last-modified timestamp (epoch millis), and a JSON payload. Three families, named by the app's own logs:

- **Node** — the workspace tree: boards, containers, instruments (timers/counters/etc.), buttons elements.
- **Session** — per-event run records (history entries) for an instrument.
- **Details** — per-event detail payloads (e.g. interval-by-interval breakdowns), id = the event's id.

### 1.1 Databases

| DB file | Role | Tables |
| --- | --- | --- |
| `desktop_debug_v25` | Live workspace store | `hf5k` (Node docs), `t3bh` (Session docs = current run state), `mq3x` (membership edges: parent id → child id, indexed by parent) |
| `history_debug_v3` | History/document store | `y9er` (Node docs), `r6vk` (Session docs + denormalized parent-id column + event-timestamp column), `ed1j` (Details docs) |
| `zk6p.sqlite` | Change outbox / sync queue (no consumer in this build) | `d3um` (scoped key/value ints), `ti9i` (queue rows with status index `idx_sync_queue_status`) |

Every doc table has the same shape: `_id TEXT PRIMARY KEY`, last-modified `INT8`, `TEXT` JSON payload. All writes are REPLACE-upserts inside explicit transactions; a row cache flushes with the transaction; after commit, changes feed the outbox. ("Node"/"Session"/"Details" labels are evidence-backed inferences over the app's own log strings — data-model §1.1–1.3, GAPS G-D1.)

### 1.2 JSON payload schemas (type id → keys)

| Type id | Family | Payload keys |
| --- | --- | --- |
| `f6im` | Node | `ra4f` name; `xeo9` color object; `me9r` icon name; `k5kp` superkind (TIME/POMODORO/STOPWATCH/AMOUNT); `w7no` app type id |
| `i8nq` / `pg1k` | Session | `crk6` duration value; `z7tz` completed flag |
| `l30j` | Session | `da3x` int (counter value) |
| `x8rd` | Session | `h3ca` list (interval snapshot) |
| `p5kw` | Details | `hy1a` list of timestamped detail items |

Session docs also carry common fields in-payload: parent Node id, two timestamps (start/end), and a string label. Nested object internals (color object, duration value encoding, detail items) are itemized only partially — data-model GAPS G-D3.

### 1.3 Instrument type ids

Persisted type ids: `g5vs` Countdown, `y9wg` Quick, `ok9y` Interval, `hz3x` Pomodoro, `s5lu` CountUp, `e2kh` Stopwatch, `m6zp` Counter (all 7 enumerated by the change observer). Clock / Container / Buttons are board-level elements without instrument classes (engine §1.1 has the id↔class↔name table with evidence).

### 1.4 Preferences (SharedPreferences; all MODE_PRIVATE)

34 app keys across 21 named stores + 8 dynamic-key stores. Groups (full per-key table with defaults and citations: data-model §3.0, settings-sounds-pro §1.0/§1.6):

- **Settings UI**: theme (`lu6b.nz0j`, Light/Dark/system), double-tap control + quick-timer naming + wait animation (`ei4h.*`), alert stream + volume (`h1th.b4dg`/`th2m`), persistent notifications (`e4eh.sb4m`), wake/full-screen notice (`e4eh.h3dv`), exact-alarm mode (`uka9.ozi7`), history retention (`uv5y.nba2`).
- **Runtime state**: current board (`lu2l.y6nz`), undo counter (`lu2l.r0hr` **(PRO)**: free = 3), scheduled alarms (`zj0o`), scheduled instrument events (`bj1l`), countdown-notice steps (`sy2f`), alert-repeat counters (`rqx8`), notification-channel registry (`h1tf.t2iz`), custom color palette (`o3pa.vh6r`), per-widget config (`jy6a.w<id>`), time-picker step (`gx8b.y5ty`).
- **Lifecycle/meta**: version stats + launch counters (`q3bu.*`), welcome shown (`nz67.st7r`), premium banner dismissed (`n8fb.i5vm`), maintenance-job timestamps (`j5gf.hc4p`, `da1p.op2t`), TTS voice/rate/pitch (`q7tv.*`), telemetry client UUID (`l4kt.c5tr`).
- **Pro (PRO)**: billing product states (`y7pr`, `m4ss`), billing connection (`us5k`), free-tier type whitelist (`mk4n.bnf2`).
- **Legacy**: `z6hs` (migrated into `bj1l` at startup).

## 2. Interchange formats

### 2.1 Board export/import — `.mtb` **(PRO)**

One UTF-8 **XML** document, MIME type `application/multitimer`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<Root class="MTB">
  <Version>1</Version>
  <Date>…</Date>
  <Board class="Board">
    <Key>k1</Key> <Name>…</Name> <Matrix>…</Matrix>
    <Timer class="CountdownTimer"> <Color>… <Icon>… <Time>… <Alert>… </Timer>
    …
  </Board>
</Root>
```

- Ids are remapped to `k1…kN` local to the file; new ids are minted on import.
- Element vocabulary (human-readable, shared with iOS): `CountdownTimer, CountupTimer, PomodoroTimer, Counter, QuickTimer, Container, Board, Timer, Item, Button, Buttons, Command, Action, Icon, Color, Time, Clock, Alert, StartAlert, FinishAlert, BreakAlert, WorkAlert, WorkTime, BreakTime, LongBreakTime, Repeats, Notice, Mode, Matrix, AdaptiveMatrix, FlexibleMatrix, Format, Condition, FinalValue, StartValue, StepValue`; command conditions spelled `inactive/active/running/waiting/completed`.
- Cross-platform: iOS-written files import on Android and vice-versa (help docs).

### 2.2 History export — CSV **(PRO)**

One CSV per timer into cache, filename = sanitized timer name (≤50 chars), shared via `ACTION_SEND_MULTIPLE` (`application/csv`) through a FileProvider. Content = the history grid as text (header + one row per entry; string cells quoted).

### 2.3 Internal JSON (in prefs, not user-facing)

Scheduled instrument events `{bvp5: [event…]}`; notice records `{nr4e: [record…]}`; widget config `{f0gd: target id, u1bg: widget type, mn9f: bool}`; alarm descriptors `{time, intent-uri}`.

## 3. What is deliberately NOT here

- **No sync/network storage**: `zk6p.sqlite`'s queue has no consumer in this build (background §6.0); no app HTTP anywhere (exclusions).
- **No migrations**: schema evolution is carried in DB *file names* (`_v25`, `_v3`); no code opens older names (G-D1).
- **SDK-owned stores** (Play, Firebase, Tenjin) are excluded from the model (exclusions file).
