# v2 — Blockers & Known Risks

> Format: one entry per item. When a chunk hits a hard stop: add an entry (Symptom / Tried / Suspected cause / Needs) and raise it — don't improvise (CONVENTIONS §6).

## Standing conditions (not blockers — constraints to build around)

1. **No headless visual verification** (Plasma portal blocks screenshots — v1 lesson). Every phase's look is user-eyeballed from the `scripts/build.sh` bundle. Widget tests assert structure/text/keys only.
2. **drift_dev 2.35.2 + Dart 3.13**: `textEnum<>()` silently breaks code generation — enum mapping stays manual in `DriftStore` (v1 workaround, still applies to every new enum-valued column, e.g. rule kinds).
3. **Fonts**: ProLisa/MonoLisa come from `/usr/local/share/fonts/`; fresh clones/builds need them (README note).
4. **Wall firing resolution = the 1 Hz ticker**: a wall fires within ~1s of its trigger (settle-based). Accepted for v2; a sub-second pre-arm is a v3 nicety if it ever matters.
5. **Clock jumps / laptop sleep**: the anchor model recomputes cleanly; a wall whose trigger passed during sleep fires at the next settle, flagged late (this is the past-due rule, not a bug).
6. **DST / timezone edge cases** remain parked (North Star §8). Times are wall-clock local; crossing DST in a day plan may drift by the offset — accepted.

## Active blockers

(none yet)
