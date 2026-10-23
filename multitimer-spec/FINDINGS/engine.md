# FINDINGS — Timer Engine Semantics (Part 4)

Part 4 · 2026-10-22 · APK: `com.persapps.multitimer` v1.14.1 (282) (per `WORK/APK-INFO.md`)
Method: static analysis of `WORK/decompiled/jadx/sources/` + `res/values/strings.xml`, anchored on `WORK/MAP.md` §"Part 4 — timer engine" and `FINDINGS/data-model.md` §1.6. Timer-type ids/classes are the vocabulary established in Part 3. All file paths relative to `WORK/decompiled/jadx/sources/` unless marked `res/` or `REFERENCE/`. Behavioral labels carry citations; "couldn't determine" items are in GAPS.

## 1.0 Timer types

### 1.1 The 10 tools (id ↔ class ↔ user-facing name)

Type ids ↔ string resources via `defpackage/ek2.java:9` (title/description/hint per id); strings resolved from `res/values/strings.xml`; class bindings evidenced per row. Superkind enum `oj2 {AMOUNT, POMODORO, STOPWATCH, TIME}` (`defpackage/oj2.java`) is what gets written into the Node document's `k5kp` field (`h.java:553-567`).

| Type id | Class | Superkind | Name (strings.xml) | Official description (strings.xml, verbatim) |
| --- | --- | --- | --- | --- |
| `g5vs` | `ka2` | TIME | Countdown | "A timer that counts down a predetermined time interval. It supports looping (auto-repeat) and delayed start." |
| `y9wg` | `xn2` | TIME | Quick | "A countdown timer without a predetermined duration. Set the time when the timer starts." |
| `ok9y` | `sk2` | TIME | Interval | "Countdown timer with the ability to add the desired number of time intervals and their repetitions. The timer supports a pause function between intervals." |
| `hz3x` | `cn2` | POMODORO | Pomodoro | "Interval countdown timer with functions of the Pomodoro technique." |
| `s5lu` | `hb2` | TIME | CountUp | "A timer that counts upward. It lets you track time from a chosen point and add notifications to stay on schedule." |
| `e2kh` | `np2` | STOPWATCH | Stopwatch | "A count-up timer that measures time intervals with an accuracy of fractions of a second. It lets you record both laps and splits." |
| `m6zp` | `ta2` | AMOUNT | Counter | "A preset step counter used to count in an increasing or decreasing manner. It lets you set both an initial value and a final one." |
| `pc5x` | — (view-level tool) | — | Clock | "A clock that lets you choose the time zone, time format, and dial style." |
| `t5ql` | — (view-level tool) | — | Container | "Container is a visual tool that allows you to run any of the timers created on one or another board directly in the container itself." |
| `he5b` | `i82`/`l82` (Buttons element) | — | Buttons | "This is an element on which you can place several buttons and assign actions to them to control other elements on the board." |

Class-binding evidence: `ka2`→g5vs and `hb2`→s5lu (`defpackage/w6.java` cases 9-10 fallback names), `xn2`→y9wg (`defpackage/mo2.java:333`), `cn2`→hz3x (`defpackage/ik2.java:229`), superkinds (`h.java:549-567`: ka2/xn2/sk2/hb2→TIME, cn2→POMODORO, np2→STOPWATCH, ta2→AMOUNT); `sk2`=Interval by elimination (4 TIME classes ↔ 4 TIME ids; Interval is the remaining one; corroborated by `MTIntervalTimerEntryActivity` in the editor family and interval fields `q84s`/`w2xs` in the model). `pc5x`/`he5b`/`t5ql` have no `ck2` instrument class — they are board items handled at view/element level (`MTInstrumentView.java:82-143` switch).

Android tool list matches `REFERENCE/timing-tools.md` ("TIMERS & TOOLS / ANDROID": Countdown, Quick, Interval, Pomodoro, CountUp, Stopwatch, Counter, Clock, Buttons). iOS adds Stepped timer and Lap timer (`REFERENCE/timing-tools.md` iOS list) — not present in the Android APK's type registry (`ek2` has exactly 10 ids).

### 1.2 Per-type engine surface (methods verbatim from the classes)

| Class | User actions (log strings) | Notes |
| --- | --- | --- |
| `ka2` Countdown | `START(lh2)` (N), `PAUSE()` (I), `RESUME()` (L), `RESET()` (K), `ADD_TIME(ji2)` (w), config `M(yo1)` | auto-repeat (`na2.p`) + autocompletion (`na2.m`) + alert config (`na2.q`); supports future start → `DELAY` event (`N`) |
| `xn2` Quick | `START(ji2)` (K — duration chosen at start), `PAUSE()` (F), `RESUME()` (I), `RESET()` (H), `ADD_TIME` (w) | no fixed duration (`REFERENCE/timing-tools.md`: "Set the time when the timer starts") |
| `sk2` Interval | `START(lh2)` (Q), `PAUSE()` (L), `RESUME()` (O), `RESET()` (N), `NEXT_INTERVAL()` (I), `NEXT_INTERVAL(i)` (J), `ADD_TIME` (w) | per-interval alerts `S(i,z)`; interval list `A()` |
| `cn2` Pomodoro | `START()` (M), `PAUSE()` (H), `RESUME()` (K), `RESET()` (J), `NEXT_INTERVAL()` (F), `ADD_TIME` (w) | work/break/long-break cycle (export tags `WorkTime`/`BreakTime`/`LongBreakTime`/`Repeats` — `sp0.java` writers) |
| `hb2` CountUp | `START(lh2)` (H — start-from point), `PAUSE()` (C), `RESUME()` (F), `RESET()` (E), `ADD_TIME` (w) | "track time from a chosen point"; supports notice schedule (`na2`-like config `G(yo1)`) |
| `np2` Stopwatch | `START()` (D), `RESET()` (B), `RESUME()` (C), `LAP()` (x) | **no Pause method exists in the class** (methods listed `np2.java:42-181`) |
| `ta2` Counter | `ADD_VALUE(i)` (w — signed step), value set `D(ra2,i)`, `RESET()` (E) | initial/final value bounds (`sa2` state: see `dy` case 1) |

## 2.0 Single-timer state machine

### 2.1 States

State enum `ja2` (`defpackage/ja2.java`): **NONE** (idle), **PREP_TIME** (pre-run preparation), **WORK** (running), **PAUSE** (paused), **COMPLETE** (reached target), **OVER_COMPLETE** (past target, awaiting finalize/reset). Interval timer uses a finer `rk2` = {NONE, PREP_TIME, WORK, **WAIT** (between-interval pause), PAUSE, COMPLETE, OVER_COMPLETE} (`defpackage/rk2.java`). Each type has an analogous per-type snapshot (`qk2`/`ia2`/`zm2`/`vn2`/`gb2`/`mp2`/`sa2` — produced by each class's `E()/D()/C()/A()/z()/y()` method).

### 2.2 Events (enum `ni2`, `defpackage/ni2.java`)

User events: `START, DELAY, RESET, PAUSE, RESUME, START_INTERVAL, SKIP_INTERVAL, INCREASE, DECREASE, LAP, COMPLETE`. System-scheduled events (delivered as alarms): `ON_START` (delayed start), `ON_FINISH` (countdown zero), `ON_START_INTERVAL`/`ON_FINISH_INTERVAL` (interval boundaries), `ON_WARNING` (pre-end alert lead), `ON_FINALIZE` (autocompletion point), `ON_SNOOZE`.

### 2.3 Transitions (Countdown `ka2` — the reference machine; all others structurally identical)

Every transition cites `defpackage/ka2.java` (method + line):

| # | From | Event | Guard | Effect | To |
|---|------|-------|-------|--------|-----|
| T1 | NONE | START (user, `N(lh2)` ka2:468-505; or button `dy.f` `dy.java`) | state==NONE && duration>0 (`ka2.java:471-478`) | clear paused-anchors; ticker start `f.Z(now or startAt)` (`ka2.java:483-485`); re-derive schedule `J()` (`ka2.java:486`); emit `START` or, if startAt>now, `DELAY` (`ka2.java:488-497`) | WORK (or scheduled start) |
| T2 | NONE (future start) | scheduled `ON_START` (alarm → `on1.c` → bus → applied) | — | transition into WORK at the scheduled moment | WORK |
| T3 | WORK | PAUSE (`I()` ka2:118-139) | state==WORK (`ka2.java:121`) | store paused-at `v=now`, remaining `w` (`ka2.java:124-129`); ticker anchor `f.p=now` (`ka2.java:133`); re-schedule `J()`; emit `PAUSE` | PAUSE |
| T4 | PAUSE | RESUME (`L()` ka2:170-187) | state==PAUSE (`ka2.java:173`) | resume ticker from now `f.U(now)` (`ka2.java:181`); emit `RESUME` | WORK |
| T5 | anything ≠ NONE | RESET (`K()` ka2:141-168) | state≠NONE (`ka2.java:145`) | ticker `f.T()` clear; re-schedule; emit `RESET`; **record history event `ot2`** with elapsed `d=gv1.M(elapsed)` and completed flag `e = elapsed ≥ total` (`ka2.java:152-161`) | NONE |
| T6 | WORK/PAUSE/COMPLETE | ADD_TIME `w(ji2)` (ka2:592-621) | state ∈ {WORK, PAUSE, COMPLETE} (`ka2.java:597-599`) | move ticker end `f.f(±delta)` (`ka2.java:606-610`); re-schedule; emit `INCREASE`/`DECREASE` with amount (`ka2.java:613-618`) | unchanged state (new end time) |
| T7 | WORK | (no event) remaining hits 0 | scheduled `ON_FINISH` fires (alarm) | → COMPLETE (alert; §3.0) | COMPLETE |
| T8 | COMPLETE | (no event) past zero, autocompletion ON | `ON_FINALIZE` fires → `c72.a` tryToAutocomplete (`defpackage/c72.java:17-35`) | log `"autocomplete timer:"`; `eq2.d()` = RESET (T5, records completed event); bookkeeping at projected end +1s | NONE |
| T9 | any | config edit `M(yo1)` (ka2:322-395) | — | applies changed config keys (color/name/icon/autocompletion `m`/duration `n`/format `o`/repeat `p`/alert `q`/notice `r`); **if any of autocompletion/duration/repeat/alert keys changed → `J()` re-schedules pending alarms** (`ka2.java:388-393`) | unchanged |

The `t92` ticker (per-instrument, `new t92(19)` `ka2.java:32`) stores **wall-clock anchors, not elapsedRealtime**: fields start-anchor `o`, paused-at `p`, accumulated `q`; `U(resumeNow)` adds the last segment `pauseAt − anchor` to the accumulation (`defpackage/t92.java:975-990`); `T()` clears (`t92.java:969-974`); `E()` = started, `D()` = paused (`t92.java:620-624`). Consequently timers are recomputable after process death; delivery across death/reboot is by exact alarms + `RECEIVE_BOOT_COMPLETED` re-registration (Part 5). No `elapsedRealtime` use exists in app code (all hits are Google SDK — `defpackage/db1.java:1050` etc.).

### 2.4 Edge cases

- **Pause during the last second:** PAUSE is legal only from WORK (`ka2.java:121`); scheduling only emits `ON_FINISH` if the computed finish is still in the future (`J()`, `ka2.java:214-217` `lh2VarD.compareTo(lh2Var) > 0`). If the pause lands after zero-crossing the state is already COMPLETE (`dy` still allows Pause buttons to no-op: interval `h()` WORK→false for Start; for Countdown a Pause command in COMPLETE matches condition COMPLETED only for Reset-type actions). Exact micro-race outcome (alarm already queued when paused) not traced → GAPS G2.
- **Edit duration mid-run:** legal without stopping — `M(yo1)` updates config and re-schedules (`ka2.java:388-393`); `ADD_TIME` is the dedicated ±-adjust while running (`T6`).
- **Delete a running timer:** repository delete (`c02.b` case 12, `defpackage/c02.java:341-372`) removes rows from main + history DBs (snapshot cached first); all pending alarms for the instrument are cancelled via `on1.a(id)` — log `"EV cancel event: <id>/*"`, intent `f4js/<id>` (`defpackage/on1.java:20-31`).
- **Two timers with the same end time:** no shared clock or coupling — each instrument schedules its own alarms, batched per instrument per timestamp (`on1.d` groups only events of the same instrument: `on1.java:96-123`). Both fire independently; simultaneous alerts are distinct notifications (per-instrument channel records `h1tf` — Part 3 §3.0). ✓ determined from architecture.

### 2.5 Formal action availability per state (commands engine view)

`dy.c()` (per type, per current state) returns the legal quick actions — e.g. Countdown (`dy.java`, case 0): NONE→{Start, Delay}, PREP_TIME→{Start(=reset+start), Reset}, WORK→{Pause, Reset}, PAUSE→{Continue, Reset}, COMPLETE→{Reset}, OVER_COMPLETE→{Start(=reset+start)}. Interval adds {Next Interval} in WORK/WAIT. Stopwatch RUNNING→{Lap, Pause, Reset}. Counter idle→{} (nothing), active→{Reset}, completed→{Reset}. (`dy.java` `c()` switch, all 7 cases.)

## 3.0 Zero-crossing behavior

For countdown-family timers (Countdown, Quick, Interval, Pomodoro), the scheduled alarms do the work:

1. **`ON_WARNING`** — pre-end alert lead: scheduled from the alert config `rt2` lead time (`y()` in ka2 = alert config, `ka2.java:638-644`; boundary `x() = max(lead,5s) − 1s` `ka2.java:626-630`). Produces the notification-countdown (`NC`) notices (`defpackage/e63.java:126-153`, `"NC registry state"`, counters in `sy2f` — Part 3 §3.0).
2. **`ON_FINISH`** — zero-crossing (`J()`, `ka2.java:218-222`): fires alert delivery (sound/vibration/full-screen — delivery mechanics are **Part 5**; the state transition is COMPLETE, `ja2.r`).
   - **Auto-repeat ON (Countdown only):** the schedule instead emits a recurring `ON_FINISH_INTERVAL` (`kl2(finishAt, duration)` — `ka2.java:208-211`), i.e. the timer loops: each zero-crossing restarts the next cycle automatically. Official: "the timer operation automatically resumes as soon as the countdown reaches zero… Auto-repeat can only be found in the Countdown timer settings" (`REFERENCE/how-tos-for-android-how-to-set-the-recurring-timer.md`).
   - **Autocompletion ON (mutually exclusive with auto-repeat):** an extra `ON_FINALIZE` alarm is scheduled at `finish + x()` (`ka2.java:223-229`); when it fires, `d72.b` routes it to `tryToAutocomplete` (`defpackage/d72.java:25-37` — only `ni2.ON_FINALIZE` maps to the autocomplete branch, `defpackage/b72.java`: `iArr[16]=1`), which RESETS the timer (`c72.java:17-35`: guard `eq2.c()` = autocompletion flag && `eq2.h()` = state==OVER_COMPLETE && `eq2.e()` projected end; then `eq2.d()` = `K()` RESET). Official: "The timer resets 10 seconds after it finishes" (`REFERENCE/how-tos-for-android-how-to-set-the-recurring-timer.md`). Code constant: `x() = max(alertLead, 5s) − 1s` (`ka2.java:626-630`) — the "10 s" is thus configurable-by-lead in code (discrepancy noted, GAPS G3).
   - **Neither on:** timer simply stays COMPLETE (OVER_COMPLETE once past zero — `h()` reports OVER_COMPLETE, `ka2.java:448-451`), requiring manual Reset (or a Start command, which resets+restarts, §4.0).
3. **Continue-past-zero:** CountUp/Stopwatch have no zero-crossing (they count up; Stopwatch records `LAP`s — `np2.x()`); Countdown family does not auto-continue as count-up — none of the state machines has a "negative counting" mode (states jump NONE→WORK→COMPLETE/OVER_COMPLETE only).
4. **History recording:** `RESET()` (manual or via autocompletion) records the `ot2` event {elapsed, completed = elapsed ≥ total} (`ka2.java:152-161`). Event kinds → history documents (`h.java:621-700`): `ot2`→Session doc `pg1k` (payload `{crk6: elapsed, z7tz: completed}`), `xm2`→`i8nq`, `aq2` (interval details list)→`x8rd` + Details doc `p5kw` (`hy1a` = per-interval detail items `dj2`, each with a timestamp), `s62` (counter value)→`l30j` (`da3x` int). Session docs also carry `edj3` (parent instrument), `xg9x`/`dg5h` (start/end instants), `d2eo` (string). **(PRO)** On flush (`dk2.k()`), Pro writes **all** events as Session+Details documents; free tier writes **only the most recent event** (`defpackage/dk2.java:40-60`: Pro clears `ck2.e` and submits the whole list; free keeps the max-by-time single event).

## 4.0 Linking & sequencing (centerpiece)

### 4.1 What exists — and what does not

**There is no autonomous timer-to-timer chaining in the engine**: no code path starts timer B as a side effect of timer A's zero-crossing. The zero-crossing pipeline is: alarm → `InstrumentEventsScheduleReceiver` (extras `j3yp`/`w8se`/`n3gs`; `com/persapps/multitimer/module/events/InstrumentEventsScheduleReceiver.java:63-99`) → `on1.c` (publish to per-instrument bus; `defpackage/on1.java:41-69`) → `mn1` handlers. The registered handlers are: autocomplete (`d72`→`c72.a`, ON_FINALIZE only), notices (`e63`), and workspace-refresh (`d72.c`) — none starts another instrument. What the app offers instead:

1. **Delayed start ("Delay")** — a timer can be started with a future (or past) start moment: `N(lh2)` with `startAt > now` emits `ni2.DELAY` and schedules `ON_START` (`ka2.java:488-497`, `J()` `ka2.java:214-217`); the `kx(ji2)` action = "start after delay" (`dy.f`: `ka2Var.N(wi0.K().d(delay))`). Official: "Delay" button with Waiting time / Start date / End date tabs; past dates start the timer retroactively "with the elapsed time" (`REFERENCE/how-tos-for-android-how-to-set-the-timer-retroactively.md`). The retroactive path is visible in `E()`: past starts compute `pastTime` and skip missed cycles (`ka2.java:88-103` — repeat-count floor over missed periods).
2. **Commands / Buttons** — condition-matched remote control (below). This is the app's actual "linking" feature.
3. **Container (`t5ql`)** — a board element that mirrors/controls timers living on *other* boards ("run any of the timers created on one or another board directly in the container" — strings.xml; wrapper `cy` in `te1.g` delegates operations to the contained instrument, `defpackage/te1.java:121-133`).

### 4.2 Command model (data)

- Command `t82 {n: TimerKey (target instrument id), o: Condition, p: Action}` (`defpackage/t82.java:7-16`).
- Condition enum `oy {INACTIVE, ACTIVE, RUNNING, WAITING, COMPLETED}` (`defpackage/oy.java`; XML spellings "inactive"/"active"/"running"/"waiting"/"completed" — `sp0.java:965-990`).
- Action hierarchy `qx`: singletons `jx.a`=**Continue**, `jx.b`=**Minus**, `jx.c`=**Get value**, `jx.d`=**Plus**, `jx.e`=**Next Interval**, `jx.f`=**Run**, `jx.g`=**Tap** (smart action), `ox.a`=**Start**, `nx.a`=**Reset**, `mx.a`=**Pause**, `lx.a`=**Lap**; parameterized `px(ji2)`=**Start for <duration>**, `kx(ji2)`=**Delay <duration>**, `hx(ji2)`=**± time**, `ix(int)`=counter **Set value**. Names from label resolver `lv4.K` (`defpackage/lv4.java:264-330`) + strings.xml (`qp6d`="Tap", `w9li`="Run", `j5cb`="Start", `nvz9`="Reset", `nm4h`="Pause", `t5it`="Continue", `nl6s`="Next Interval", `zlj7`="Lap", `ggk2`="Plus", `ivj1`="Minus", `r3bv`="Get value", `gt1a`="Start for %s"); icons in `ub2.a` (`defpackage/ub2.java:22-59`: inst_start/inst_reset/inst_pause/inst_resume/inst_next/inst_lap/inst_increase/inst_decrease/inst_quick_start/inst_delay). Sync payload keys: `k5z7`/`m2xi`/`m6qp` (`g45.java:138-154`); export XML `<Command><TimerKey>/<Condition>/<Action>` (`sp0.java:961-993`).
- Buttons element: `l82` (Buttons doc, `.j` = button list) → `m82` (one button: label, color, command list) → commands. Up to **3 buttons per element** (official: `REFERENCE/guides-buttons.md`; UI `MTButtonsItemActivity` in manifest). Import remaps TimerKeys through the id map (`qd.java:303-325`, `vz3.P`).

### 4.3 Command execution semantics

- **Condition matching:** the currently-matching condition set is computed per type from the live state — `dy.e()` (`defpackage/dy.java`): e.g. Countdown WORK → [ACTIVE, RUNNING]; PAUSE → [ACTIVE, WAITING]; COMPLETE → [ACTIVE, COMPLETED]; PREP_TIME → [ACTIVE, WAITING]; NONE/OVER_COMPLETE → [INACTIVE]. A command fires **only if** its condition ∈ the target's current set (execution pipeline `zx.f` builds condition-filtered per-command units — `defpackage/zx.java:47-70`; official rule: "If the current status of the tool does not match the one specified in the button settings, no action is performed" — `REFERENCE/guides-buttons.md`).
- **Start semantics:** plain `Start` from NONE = normal start; from any active/complete state = **reset-then-start** (`dy.f`: `K() && N(null)` — Countdown; identical pattern CountUp/Quick/Interval/Stopwatch). `Delay` = `N(now + kx.a)`.
- **Tap (`jx.g`)** = the per-state smart action (button-on-board quick toggle): Countdown NONE→Start, PREP_TIME→Reset, WORK→Pause, PAUSE→Continue, COMPLETE→Reset, OVER_COMPLETE→Start; Stopwatch WORK→**Lap**; Interval WAIT/PAUSE→Continue, WORK→Pause, PREP/COMPLETE→Reset (full tables `dy.d()` case 0/3/5… `defpackage/dy.java`). The overlay quick-buttons per state are gated identically (`zd.java:82-110`).
- **Pause propagation:** none automatic — pausing one timer never pauses another; a Pause *command* can target any timer whose current condition set contains a Pause-compatible condition (Pause only applies from RUNNING per `dy.f/i/…`).
- **Get value (`jx.c`)** is read-only — explicitly excluded from mutation (`dy.d()`: `if (!qxVar.equals(jx.c)) { apply }`) — it returns the current value/remaining (used for display/command feedback; `ty`/`ry` result wrappers).
- **Cycles (A→B→A):** not representable — commands are only executed by user button press; there is no rule engine that fires them on timer events. (Same conclusion for the deprecated global "Commands": help doc describes them as manually pressed lists — `REFERENCE/guides-buttons.md` "WHAT IS THIS FUNCTION?".)
- **Limits:** one action per tool per button ("The button must contain only one action on the same tool" — `REFERENCE/guides-buttons.md`); buttons act only on tools of their own board (official, ibid.); **Clock and Buttons tools cannot be commanded** (`defpackage/n50.java:41` registry covers only the 8 types g5vs/y9wg/ok9y/s5lu/hz3x/e2kh/m6zp/t5ql); per-type action menus differ (registry: e.g. Pomodoro gets {Start, Pause, Reset, Next Interval}, Stopwatch {Start, Lap, Pause, Reset}, Counter {Set value, Reset} only, Container {Pause, Continue, ±, Reset}).
- **Pro gating:** "The 'Buttons' function is only available with the Pro upgrade" (`REFERENCE/guides-buttons.md`); **(PRO)** enforcement hooks seen in Part 3 (`mk4n.bnf2` free-type whitelist) and `gj.a(context)` checks around creation flows (`fw3.java:20-24`).

## 5.0 Boards & concurrency

- **Concurrent timers:** unlimited; each instrument owns an independent ticker + independent alarm set (§2.4 "same end time"). No global constraint found in code or docs.
- **Boards are views over global documents:** instruments are documents (`hf5k`) with membership edges (`mq3x`); switching boards does not stop or pause anything — scheduled events are keyed by instrument id globally (`on1.b()` lists all scheduled instruments; `bj1l` store keys = instrument ids, Part 3 §3.0). The side-menu "Commands" (deprecated predecessor of Buttons) could act across boards (`REFERENCE/guides-buttons.md`).
- **Container:** a board element that embeds another board's timer and exposes full operation (`te1.g` wraps contained instruments in the same `dy` operations; `cy` container-op wrapper). Layout engine: boards have default/adaptive/flexible matrix layouts (export `Matrix`/`AdaptiveMatrix`/`FlexibleMatrix` elements — `sp0.java:1010-1022`; flexible layout required to resize Buttons — `REFERENCE/guides-buttons.md` "Important notes").
- **Workspace persistence:** every command application ends with `m95Var.n(instrument)` = persist + notify (`dy.d()` all cases), which flushes to `desktop_debug_v25` and pushes observers (Part 3 §2.0).

## GAPS

- **G1 — Interval/Pomodoro internal phase algebra:** `sk2` (969 ln) and `cn2` (886 ln) state computations (`E(lh2)`/`D(lh2)`) were mapped at the surface (methods, states, per-interval alerts) but not line-by-line; exact boundary math (e.g. whether WAIT phases count into total, prep-time defaults) not extracted. What was tried: method-map + state enums + `dy` application semantics; deeper tracing deemed low-yield per task §6.0.
- **G2 — Pause/zero micro-race:** whether a queued ON_FINISH alarm still fires after a last-instant PAUSE (and what state results) was not determined; scheduling code omits ON_FINISH when finish ≤ now (`ka2.java:214-217`), suggesting no fire, but the alarm-cancel path for that specific race wasn't traced.
- **G3 — Autocompletion delay constant:** help doc says "resets 10 seconds after it finishes"; code computes `max(alertLead, 5s) − 1s` (`ka2.java:626-630`) — either the default lead is 11 s somewhere in `rt2` defaults (not verified) or the doc rounds. Not reconciled.
- **G4 — `hg` import map** (`defpackage/hg.java:14`) lacks the "active" condition spelling that the exporter can emit (`sp0.java:972-973`) — possible import gap for Active-conditioned commands; not verified end-to-end.
- **G5 — PREP_TIME origin:** which config enables the PREP_TIME phase (observed in states + conditions but not in the `M(yo1)` key list; likely Pomodoro/Interval prep setting) — not pinned.
- **G6 — XAPK locale splits** were not decoded (Part 2 note); strings cited are the default (English) `res/values/strings.xml`.

## CONFIDENCE

**High** for: the type table (ids↔classes↔names — three independent sources: `ek2` strings, `oj2` superkinds, pinned fallbacks), the Countdown state machine and all its transitions (`ka2` is fully decompiled and cited), the command model + execution semantics (`dy`/`zx`/`oy`/`qx` + `n50` registry + help-doc agreement), zero-crossing scheduling (`J()` + `on1` + receiver extras), and the history recording flow (`ot2`/`h.java` bridge).

**Medium** for: Interval/Pomodoro internals (surface mapped, algebra gapped — G1), the autocompletion timing discrepancy (G3), absence-of-auto-chaining claim (stated from exhaustive handler inventory `d72`/`e63`/workspace-refresh; a hidden handler cannot be fully ruled out in a 6,460-file defpackage, though every `mn1` consumer of the event bus that could be found was inspected).

**Low** for: none load-bearing.
