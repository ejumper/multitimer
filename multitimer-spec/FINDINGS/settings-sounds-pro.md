# FINDINGS — Settings, Sounds, Pro-Gating (Part 7)

Part 7 · 2026-10-22 · APK: `com.persapps.multitimer` v1.14.1 (282) (per `WORK/APK-INFO.md`)
Merges: preference keys (`FINDINGS/data-model.md` §3.0 — normative for key/type/default), settings screens (`FINDINGS/ui-structure.md` §1.0/§2.0), engine/background effects (`FINDINGS/engine.md`, `FINDINGS/background-and-alerts.md`), strings (`res/values/strings.xml`). `**(PRO)**` marks gated items. Paths relative to `WORK/decompiled/jadx/sources/` or `res/` as marked.

## 1.0 Settings inventory

### 1.1 Alert Settings (`AlertSettingsActivity` → `a_settings_alert_settings_activity`)

| UI control | Pref | Default | Effect (cited) |
| --- | --- | --- | --- |
| Alert stream selector (Media / Alarm / Notification) | `h1th.b4dg` (int) | 4 = Alarm | Maps to `AudioAttributes`/vibration usage at play time: 3→`USAGE_MEDIA`(1), 4→`USAGE_ALARM`(4), else→`USAGE_NOTIFICATION`(5) (`defpackage/r62.java:126-133`, `nl2.java:556-566`, `cu2.java:117-155`); label strings `p7md` (media volume), `dk7y` ("behave like alarms… even in Do Not Disturb"), `u3pk` (standard notifications) (`AlertSettingsActivity.java:94-115`) |
| Alert volume slider | `h1th.th2m` (int, optional) | absent = system volume | Volume forced after DND-off during alert session (`r62.b()` `r62.java:96-102`; applied `r62.java:141-164`) |
| Persistent countdown notifications | `e4eh.sb4m` (bool) | false | Master toggle of the NC keeper: on → rebuild all (`k63.d()`), off → cancel all (`h63.d()` `defpackage/h63.java:105-121`; switch `notice_state_switch` `AlertSettingsActivity.java:74-77`) |
| Full-screen (wake) notices | `e4eh.h3dv` (bool) | true | Sets the wake-when-locked hint on alert models (`x2.java:140-157`); note Part 5 §4.0: no FSI consumer found (G2 there) |
| "Use as System Alarm" (exact-alarm channel) | `uka9.ozi7` (bool) | false | Alarm scheduling mode: false → `setAlarmClock` (default), true → `setExactAndAllowWhileIdle` (with API-31 degradation) (`defpackage/lz3.java:99-147`; switch `clock_alarm_disabled_switch` `AlertSettingsActivity.java:78-87`) |
| Do Not Disturb access | (system `isNotificationPolicyAccessGranted`) | — | Toggle opens the system DND-access intent; when granted, alerts auto-lift DND (`r62.java:135-164`, permission `ACCESS_NOTIFICATION_POLICY`) |

### 1.2 Controls (`ControlsSettingsActivity`, store `ei4h`)

| UI control | Pref | Default | Effect |
| --- | --- | --- | --- |
| Double-tap switch | `ei4h.y5gz` (bool) | true | Double-tap = start/stop on instrument views (`ae2.java:158-166`, `jf2.java:99-107` — per data-model §3.0) |
| Ask name for quick timer | `ei4h.i9in` (bool) | false | Quick-timer creation prompts for name (`quick_timer_name_switch`, `ControlsSettingsActivity.java:69-74`) |

### 1.3 History (`HistorySettingsActivity`)

| UI control | Pref | Default | Effect |
| --- | --- | --- | --- |
| Keep records | `uv5y.nba2` (String) | default = forever | Retention encoding `jaq2` (forever) / `e6zq:<years>` / `qys9:<days>`; enforced by the daily maintenance job (`mf5.J/W` `mf5.java:205-223,590-615`; `ag1.java:20-31`) **(PRO)** — free tier doesn't persist history at all (`dk2.java:49-60`, engine §3.0) |

### 1.4 Optional settings (`ExtraSettingsActivity`)

| UI control | Pref | Default | Effect |
| --- | --- | --- | --- |
| Wait animation | `ei4h.w8an` (bool, inverted) | false (animation on) | Spinning-wait overlay on long ops (`c_progress_window`) (`ExtraSettingsActivity.java:23-31`) |

### 1.5 Appearance / badge / display (from iOS screenshots; Android state)

- **Theme**: `lu6b.nz0j` (enum `ip4`, default SYSTEM) — "Light theme"/"Dark theme" strings `hm4u`/`xi8b` (data-model §3.0 `g64.java:55-62`); applied via AppCompatDelegate (`ot5.java:375-386`). No per-color themes on Android (Part 6 §5.0 G4).
- **Badge / Display Settings / iCloud Sync** (iOS rows): no Android settings activities exist for them (negative cross-check, Part 6 §2.0).

### 1.6 Other app-managed prefs (not in settings UI; meanings per data-model §3.0)

Current-board `lu2l.y6nz`; undo counter `lu2l.r0hr` **(PRO)** (§3.0); channel registry `h1tf.t2iz`; scheduled alarms `zj0o` + instruments `bj1l` + NC state `sy2f`/`rqx8` + legacy `z6hs` (background §2.0/§3.0); version stats `q3bu.*`; TTS voice/rate/pitch `q7tv.n4me/r8te/p6ch`; custom colors `o3pa.vh6r`; maintenance timestamps `j5gf.hc4p`/`da1p.op2t`; picker step `gx8b.y5ty`; per-widget config `jy6a.w<id>`; telemetry client UUID `l4kt.c5tr`; welcome-done `nz67.st7r`; premium-banner dismissed `n8fb.i5vm`; pro whitelist `mk4n.bnf2` **(PRO)**; billing states `y7pr`/`m4ss` **(PRO)**.
**Correction to Part 5 §4.0**: `y7pr`/`m4ss` are **not dead** — they are the Play-billing product-state stores, written via `"GP setProductState"`/`"GP clearMissingProductTime"` (`defpackage/fb2.java:585-615,1117-1127`), wired in `wb1`'s constructor (`defpackage/wb1.java:21-30`); likewise `us5k` is constructed by `km1(context,22)` inside `wb1` (`wb1.java:20`, `km1.java:87-89`) — billing connection state, not unused. Part 3's table was right.

## 2.0 Sounds & alert assets

### 2.1 `res/raw/` inventory (complete — 4 files)

| File | Class | Purpose |
| --- | --- | --- |
| `alarm_6s.mp3` | `nn2.d1aw` "Alarm" (6 s) | Built-in alert sound #1 (`defpackage/nn2.java:23-27`) |
| `alarm_1s.mp3` | `nn2.j8cr` "Short alarm" (1 s) | Built-in alert sound #2; **the default** (`x2.g()` → `nn2.f`, `x2.java:52-60`) |
| `com_android_billingclient_heterodyne_info` / `_registration_info.binarypb` | Play Billing SDK | Not sounds — billing SDK config blobs (excluded, §4.0/`FINDINGS/exclusions.md`) |

Played via `MediaPlayer` with loop-when-duration-exceeded + auto-stop (background §5.0); no other raw audio assets exist.

### 2.2 Sound sources & custom sounds (recap, cited from background §5.0)

- Sound library screen: `a_sound_list_activity` (`SoundsActivity`); sources = built-ins (`nn2`, `android.resource://`), **device sounds** via SAF `ACTION_GET_CONTENT`/`OPENABLE` (`vn2.w` case 1, `vn2.java:1050-1058`) copied to **cacheDir** (`ec4.java:107-175`), and **TTS-synthesized** sounds (`TextToSpeechActivity` → file, named `"<text>"`, `mo4.java:36-71`). REFERENCE how-to (`how-tos-for-android-how-to-add-custom-sounds.md`) describes copying to the device `Ringtones` folder first — the in-app picker path supersedes it in code.
- Custom-sound persistence answer for Part 3 G6: imported sounds are cache-dir files referenced by descriptor (`ut2{name,duration,…}` inside alert config); no sound DB/copy into filesDir was found — OS cache clears can invalidate them (flagged in background §5.0 and here as the final answer).

## 3.0 Pro-gating — definitive

### 3.1 The flag and the catalog

- **Accessor**: `gj.a(Context)` = single source of truth (`defpackage/gj.java:16-26`): delegates to `cl3.a()` (Application singleton `E`), with a Firebase Test Lab bypass (`zo3.n.a(3)`). `gj.b(Context)` = `null` if pro else `1` (free marker, `gj.java:28-30`).
- **State**: `cl3.a()` = for each catalog product, `wb1.b(productId) == wl3.PURCHASED` → pro (`defpackage/cl3.java:24-39`). Purchase states {PURCHASED, PENDING, UNDEFINED} (`wl3.java`).
- **Catalog** (`kb1.java:13-20`): 4 Play products — **`by8t`** type `PURCHASE` (one-time) and **`o5bs` / `n2ck` / `v9mx`** type `SUBS/SUBSCRIPTION` (`nb1.java`). Matches REFERENCE exactly: "Monthly Subscription, Annual Subscription, and One-Time Payment… one license expressed as Pro-upgrade activation" (`REFERENCE/faq.md:95-101`); "subscription basis for one month to one year. A one-time purchase is also offered" (`REFERENCE/multitimer-android-app-features.md:280-281`).
- Billing stack: `wb1` = BillingClient manager (Koin singleton) (`wb1.java:17-30`); PairIP `com/pairip/licensecheck` = separate app-integrity/license wrapper (see exclusions file; not a feature gate).

### 3.2 Check-site table (exhaustive — 25 sites in 22 files)

`gj.a`/`gj.b` referenced ONLY in the files below (rg sweep, sources+com/persapps; `gj.java` itself excluded). Feature attribution per surrounding code:

| File:line | Gate |
| --- | --- |
| `vn2.java:1037` (`.v()`) | **Board count**: free limited to **1 board** (`((List) this.q).size() < gj.b()`; `gj.b`=1) — adding boards in drawer blocked |
| `j0.java:286` | **Instruments per board**: free cap **12** (`gj.a ? null : 12`; `board.l().c()+1 <= 12`) — else dialog `tk3.b` |
| `aq1.java:22-37` | **Interval repeat = 0** ("disable the interval") Pro-only unless the interval type id is whitelisted in `mk4n.bnf2` (dialog `e4p3`/"Upgrade to PRO" + `q6sj`); whitelist populated from existing zero-interval interval-timers (`bu.java:203-217`) — shim semantics, see GAPS |
| `fw3.java:17-58` | **Undo last action**: free gets **3 trials** (`3 − lu2l.r0hr`), then Pro dialog (`oa6f` "Free Version" / `cn5q` "…three trial attempts…") |
| `dk2.java:49-60` | **History persistence**: pro flushes all events; free keeps only the newest (engine §3.0; REFERENCE: history "not saved… only until the next start" `multitimer-android-app-features.md:197`) |
| `zf1.java:755-760` | **Buttons/Commands execution**: running a command targeting a Buttons element (`i82`) blocked for free (`tk3.a(activity,"y6mv")` → Pro screen) |
| `o.java:241-247` | Same Buttons-element gate in the board popup list |
| `jv2.java:52-75` | Pro-feature presentation flow for free users (`gj.b()!=null` → feature banner `av2(2)`) |
| `xk2.java:958`, `wa2.java:857`, `ma2.java:756`, `lb2.java:1171`, `gn2.java:2096`, `ao2.java:559` | **Hide Pro-only editor rows** for free: `add_time_section` (Add Time Buttons) / `add_value_section` (Add Value Buttons) invisible until pro |
| `ye4.java:211`, `x7.java:223`, `sq4.java:276`, `ii3.java:279` | Settings pages (alert/controls/history/extra families) show the **`limit_view` upsell banner** (`a_history_limit_view`) when free |
| `h64.java:49-60` | Pro/fragment: hides `multitimer_pro_section` when already pro; theme row wiring |
| `uq.java:272-277` | ProVersionFragment: already-pro → "purchases restored" message path (`nyq1`) |
| `qk2.java:1024-1036` | Side menu: premium-tinted element (`app_contentPremium`) shown to free, plain to pro (banner row; dismissal pref `n8fb.i5vm`) |
| `SoundsActivity.java:113,169,176` | **TTS sounds** (menu `add_tts_sound` → `tk3.a(this,"text to speech")`) and **custom device sounds** (`add_custom_sound` → `tk3.a(this,"device sound")`) are Pro-only; TTS-service availability also only probed when pro |

### 3.3 The definitive gated-feature list (D4 answer)

1. **Multiple boards** (free = 1) — code + REFERENCE `multitimer-android-app-features.md:365-366` ✓
2. **>12 instruments per board** — code + REFERENCE `:356,73` ✓
3. **Flexible board layout** (resize/move/overlap) — REFERENCE `:377-380`; code gate via editor/layout dialog (flexible writer `sp0.java:1042`; no `gj` site — layout option gated upstream in board-layout UI, see GAPS)
4. **Buttons (command buttons) incl. their execution** — code (zf1/o) + REFERENCE `guides-buttons.md:96` ✓
5. **History storage + CSV export** — code (dk2) + REFERENCE `faq.md:65` ✓ **(PRO)**
6. **Export/Import boards** (`.mtb`) — REFERENCE `faq.md:65` ✓; code gate via export dialog flow (see GAPS)
7. **Undo last action** beyond 3 trials — code (fw3) ✓
8. **Add Time / Add Value Buttons configuration** — code (6 hide-sites) ✓ (unlisted in REFERENCE Pro bullet list — superset)
9. **Custom device sounds + Text-to-Speech sounds** — code (SoundsActivity) ✓ (unlisted in REFERENCE bullets — superset)
10. **Interval repeat = 0** — code (aq1 dialog text) ✓ (unlisted in REFERENCE — superset)

Hypothesis "pro = multiple boards" — **confirmed but incomplete**: board count is one gate among ten; the full list above is the answer.

### 3.4 Nag / purchase flow (once)

Free users hit dialogs (`lz2` titled "Upgrade to PRO"/"Free Version") or `tk3.a(activity, <tag>)` navigation to the Pro screen (`ProVersionActivity`/`ProVersionFragment`: feature list `a_pro_version_feature`, offers `a_pro_version_offer`, restore path `nyq1` "Your purchases were restored successfully!"). Purchase states cached in `y7pr`/`m4ss` (§1.6 correction). A premium banner row exists in the side menu, dismissible (`n8fb.i5vm`). No nag loops found beyond limit-triggered dialogs + the banner.

## 4.0 Non-sound asset inventory (names + purpose only)

- **Instrument icons** (preset icon set, `res/drawable-nodpi/icons8_*.png`, 42): ambulance, bar, beach, birthday-cake, butterfly, calendar, cards, chip, clown-fish, comedy, controller, cooking-pot, crystal-ball, dashboard, dog, dumbbell, eggs, exercise, globe-earth, home, king, language, laptop, meditation-guru, micro, musical, novel, people-in-car, phone-office, private-emoticon, regular-biking, retro-alarm-clock, shipped, spade, sprout, star, summer, tea-cup, time, tooth-cracked, washing-machine (±2) — the `IconsActivity` picker set.
- **Onboarding art**: `welcome_back_01–17.png` (backgrounds), `welcome_content_01–18.png` (slide content) — `WelcomeActivity` fragments.
- **App/UI vectors** (`res/drawable/*.xml`): `ic_menu`, `ic_move`, `ic_widget_actions`, `ic_widget_settings`, `dot_background`, `widget_progress_default`, menu-cell/checkbox/switch selectors (app) + `$mtrl_*`/`$avd_*` (library). Launcher icons: `mipmap-*/` (adaptive).
- **Font**: `res/font/condensed_regular.ttf` — the only bundled typeface (timer digits, widget values; Part 6 §5.0).
- **Widgets previews**: `widget_*_view_preview` layouts as `previewLayout` (no preview images, `previewImage=@null`).

## GAPS

- **G1 — Flexible-layout and Export/Import gate sites**: REFERENCE lists them as Pro, but no direct `gj` check site was found (they are likely gated inside the board-layouts dialog / export dialog flows in obfuscated classes without a `gj` reference — e.g. option rows filtered by pro state). Bounded search documented; exact lines not pinned.
- **G2 — `mk4n.bnf2` whitelist semantics**: population code records type ids of zero-interval interval timers (`bu.java:203-217`) — i.e. the whitelist appears to flip per-device based on existing documents; whether this is a compatibility shim (grandfathering pre-Pro-created 0-repeat timers) or something else is interpretation, not fact.
- **G3 — `km1(22)/us5k` key names**: billing connection store constructed (`wb1.java:20`) but its key layout wasn't enumerated (keys written by `ub1`/`tb1` listeners unread).
- **G4 — Product metadata**: human-readable product names/prices live server-side (Play Console); only obfuscated ids are in the APK.

## CONFIDENCE

**High** for: the settings inventory (every switch read directly in the readable activities with pref + effect citations), `res/raw` classification (4/4 files), the pro flag chain (`gj`→`cl3`→`wb1` all read), the 25-call-site gate table (exhaustive rg sweep + per-site context read), the catalog shape (4 products ↔ faq's 3 payment periods + one-time), and the exclusion list (ISLANDS §1 directly).

**Medium** for: the `bnf2` whitelist interpretation (G2), flexible-layout/export gate placement (G1), and iOS-vs-Android feature parity beyond the documented lists (REFERENCE describes both platforms; Android deltas noted inline).
