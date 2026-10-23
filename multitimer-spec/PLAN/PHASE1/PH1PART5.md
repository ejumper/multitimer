# PH1PART5 — Background Operation & Alert Delivery

Part of [Phase 1](./OVERVIEW.md). [CONVENTIONS.md](./CONVENTIONS.md) binds this task.

## 1.0 Objective

Document how timers stay accurate and how alerts are delivered when the app is
backgrounded, killed, or the device reboots — plus any sync/backup behavior the
Android app actually performs.

## 2.0 Prerequisites (STOP if unmet)

- `FINDINGS/data-model.md`, `WORK/MAP.md` (manifest digest + "Where to look →
  background").

## 3.0 Procedure

1. **Services:** for every service in the manifest (MAP has the list): its class,
   purpose, foreground-service type, what it does per period (notification updates?
   sound loop?). `rg`: `startForeground|ForegroundService`.
2. **Scheduling:** `rg`: `AlarmManager|setExact|setWindow|WorkManager|JobScheduler|JobInfo`.
   Determine the strategy: exact vs inexact alarms, alarm re-scheduling rules
   (per timer? consolidated?), behavior under Doze (`*AllowWhileIdle`?).
3. **Reboot/kill recovery:** BOOT_COMPLETED receiver — what state is restored, are
   interrupted timers resumed or marked? `rg`: `BOOT_COMPLETED|RECEIVE_BOOT`.
4. **Notifications:** channels created (`NotificationChannel`), per-channel purpose,
   notification content/updates while running, ongoing flags, actions on the
   notification (pause/stop/+1min?).
5. **Alert delivery at zero:** sound playback mechanism (`MediaPlayer|SoundPool`),
   loop count/duration, vibration patterns, LED/heads-up, "alert until acknowledged?"
   behavior, per-timer alert selection (ties to Part 7 sound inventory).
6. **Sync/backup reality check:** within APP code only: `rg`: `okhttp|Retrofit|api/|upload|sync`.
   Expected outcome is possibly "none — local only" (iOS sync is iCloud, Android may
   differ) — but VERIFY and document what is actually there (Google backup rules in
   `res/xml/` too).

## 4.0 Deliverables

`FINDINGS/background-and-alerts.md` per CONVENTIONS format, sections mirroring 3.1–3.6
above, plus `## GAPS` / `## CONFIDENCE`.

## 5.0 Self-Verification Checklist

- [ ] Every manifest service and receiver from MAP is accounted for (purpose or
      explicitly unknown)
- [ ] Alarm strategy stated with citations (exact/inexact, per-timer or consolidated)
- [ ] Reboot behavior answered definitively (or gapped explicitly)
- [ ] Sync section answers "does the Android app sync anything anywhere" with evidence

## 6.0 Notes

This part pairs tightly with Part 4 (engine). If you discover engine-behavior facts
while in here (e.g. what "finished" means for a backgrounded timer), write them to
YOUR findings and add a one-line pointer note — do not edit Part 4's findings file.
