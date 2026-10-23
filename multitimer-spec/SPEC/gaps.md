# SPEC — Gaps

Everything not determinable from v1.14.1 (282), consolidated from the six FINDINGS gap lists (29 entries → 21 items; 8 resolved during synthesis, listed at the end). Confidence: **low** = likely unrecoverable without dynamic analysis; **medium** = one focused decompile session away.

## A. Engine

- **G-E1 — Interval/Pomodoro internal phase algebra** (from engine G1): boundary math of WAIT phases, prep-time defaults, exact interval/total accounting. *Evidence*: state enums, action sets, per-interval alerts, and export fields are documented; the tick-level computation was not traced (969/886-line classes). **Medium** — rebuild can proceed with observable behavior; verify against device.
- **G-E2 — Pause/zero-crossing micro-race** (engine G2): whether an already-queued ON_FINISH fires after a last-instant pause. *Evidence*: scheduling omits ON_FINISH when finish ≤ now, suggesting no fire. **Low** without dynamic testing.
- **G-E3 — Autocompletion delay: doc says 10 s, code computes `max(alertLead, 5 s) − 1 s`** (engine G3). Contradiction surfaced per README: default lead may be 11 s somewhere in defaults (unverified) or the doc rounds. **Medium** — pick code behavior for rebuild; confirm lead default on device.
- **G-E4 — `.mtb` importer's "active" condition spelling** (engine G4): exporter can emit `active`; the obfuscated import map shows the other four spellings — possible import gap. **Medium**.
- **G-E5 — PREP_TIME phase origin** (engine G5): which config enables the pre-run preparation phase (observed in states/conditions, absent from the config-update key list). **Medium**.

## B. Data model

- **G-D1 — DB role split and naming generations** (data-model G1, G7): "live workspace" vs "history store" roles are evidence-backed inference (log strings + consumers), not stated anywhere in the binary; no code opens older `_v*` DB names; `uc1y` store remains unexplained (`us5k` was resolved = billing). **Medium**.
- **G-D2 — Per-field `.mtb` schemas for every tool type** (data-model G2): envelope, vocabulary, and 3 example adapters documented; field-by-field expansion per class not enumerated. **Medium** — traceable from the cited export adapters when needed.
- **G-D3 — Nested JSON payload internals** (data-model G3): color object, duration-value encoding, detail-item keys not itemized. **Medium**.
- **G-D4 — Residual type-id mapping** (data-model G4): 7 instrument ids resolved (Part 4), but `ok9y`↔Interval rests on elimination + corroboration rather than a direct pin. **Medium**.
- **G-D5 — Buttons/Commands document representation** (data-model G5): export classes exist; internal type id of Buttons elements not traced. **Medium**.
- **G-D6 — `zk6p.sqlite` scope constants** (data-model G9): queue names/scopes are runtime constants not enumerated; consumer absence proven (Part 5). **Low priority** — the table can be omitted from a rebuild or kept as a change-log.

## C. Background / delivery

- **G-B1 — In-app-suppression predicate** (background G1): the exact check (resumed vs task-root) behind skipping alert notifications while the app is open. **Medium**.
- **G-B2 — Wake-when-locked hint consumer** (background G2): `m84.g`/`h3dv` sets a hint no reader consumes in the traced path; possibly inside jadx-failed methods. A rebuild should implement lock-screen wake deliberately (docs promise alarm-like behavior) rather than copy the ambiguity. **Medium**.
- **G-B3 — Alarm-descriptor replay** (background G3): boot re-arm covers instrument events + countdown notifications; whether any other alarm class replays its persisted descriptors after reboot was not fully traced. **Medium**.
- **G-B4 — SDK-37 foreground-service threshold literal** (background G4): taken at face value from decompiled code (Android 16+ hosts playback in an FGS); behavior on 14/15 documented as serviceless playback. **Medium**.
- **G-B5 — Diagnostics cadence config** (background G5): local-only confirmed; retention/upload-cadence keys unread. **Low priority**.

## D. UI

- **G-U1 — Row/consumer bindings inside obfuscated classes** (ui G1): adapters inflate rows by inlined int ids; layout→consumer mapping below screen level is by naming. **Accepted** (bounded per plan).
- **G-U2 — Shared settings page shell consumer** (ui G2): which settings activities inflate the shared shell directly. **Low priority**.
- **G-U3 — Clock dial-style option set** (ui G3 adjacent): editor exists; the enumerated style list was not extracted. **Medium**.
- **G-U4 — Android color themes** (ui G4): iOS-only per evidence sweep; a hidden Appearance option can't be fully excluded. **Medium**.
- **G-U5 — Welcome flow step order** (ui G5): fragment content unread (first-run only). **Low priority**.

## E. Pro / licensing

- **G-P1 — Flexible-layout and Export/Import gate sites** (settings-sounds-pro G1): both are documented Pro features with no direct `gj` check site found — gating presumably inside obfuscated dialog flows. Rebuild: gate them as Pro per docs. **Medium**.
- **G-P2 — `mk4n.bnf2` whitelist semantics** (settings-sounds-pro G2): populated from existing zero-interval interval timers; grandfathering-shim interpretation is inference. **Medium**.
- **G-P3 — Billing connection store keys** (settings-sounds-pro G3): `us5k` purpose known, key layout unread. **Low priority**.
- **G-P4 — Product names/prices** (settings-sounds-pro G4): server-side (Play Console); only obfuscated ids in APK. **Inherent**.

## Resolved during synthesis (no longer gaps)

1. Custom-sound persistence → cache-dir files referenced by descriptor (Part 5 §5.0).
2. `y7pr`/`m4ss` "dead stores" → live billing product-state stores (Part 7 §1.6 correction).
3. `us5k` unused → billing connection store (Part 7).
4. Template gallery storage → website-only; no app feature (Part 7 string sweep; data-model G8 closed).
5. Sync engine → none exists; outbox has no consumer (Part 5 §6.0; data-model G9's consumer half closed).
6. Free-tier history phrasing → code behavior authoritative (only newest event kept).
7. Full instrument type table → Part 4's 10-tool table superseded data-model G4 (residual G-D4 only).
8. `hg` import map vs exporter conditions → kept as G-E4 (partially open).
