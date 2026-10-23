# PH1PART7 — Settings, Sounds, Pro-Gating, Exclusions

Part of [Phase 1](./OVERVIEW.md). [CONVENTIONS.md](./CONVENTIONS.md) binds this task.

## 1.0 Objective

Finish the recon edges: full settings inventory, sound/alert asset mapping, determine
exactly what "pro" gates (marked inline everywhere), and write the exclusion list
(ads/analytics/crash/billing SDKs) so later phases know what to ignore forever.

## 2.0 Prerequisites (STOP if unmet)

- `FINDINGS/data-model.md` (preference keys), `WORK/MAP.md`, `WORK/ISLANDS.md`,
  `FINDINGS/ui-structure.md` (settings screen exists? where?).

## 3.0 Procedure

1. **Settings inventory.** Merge: preference keys (Part 3) + settings-screen structure
   (Part 6) + strings. For each setting: name, type, default, options, effect (cite
   engine/background findings for the effect — e.g. "pref X → engine does Y" per
   FINDINGS/engine.md).
2. **Sounds & alert assets.** Full `res/raw/` inventory with filename → which alert
   context (per strings/usage `rg -n "R.raw\."`). List custom-sound import support if
   present (file picker → where stored).
3. **Pro-gating.** `rg -l "billingclient|Purchase|isPro|premium|subscri"` in APP code.
   Find the flag/state and EVERY check site → the definitive list of gated features.
   Working hypothesis (unverified): pro = multiple boards. Confirm or correct with
   evidence. Also note trial/nag behavior in-app (once — no detail needed).
4. **Exclusion list.** From ISLANDS.md SDK labels, write the definitive "ignore
   forever" list: ads / analytics / crash / billing SDK packages. One line each.
5. **Asset inventory (non-sound):** app icons, images that carry meaning (preset timer
   icon sets?) — NAMES and purpose only; never plan to copy assets.

## 4.0 Deliverables

`FINDINGS/settings-sounds-pro.md` (sections 1.0–4.0 above) and
`FINDINGS/exclusions.md` (section 3.4), both per CONVENTIONS format with
`## GAPS` / `## CONFIDENCE`.

## 5.0 Self-Verification Checklist

- [ ] Every preference key from data-model.md appears with a meaning
- [ ] Pro-gate list is exhaustive: every code check-site listed with citation
- [ ] Every `res/raw/` file classified
- [ ] Exclusion list covers every SDK island labeled in ISLANDS.md

## 6.0 Notes

The pro-gate list directly answers D4. If billing logic is obfuscated, evidence may be
partial — say so in CONFIDENCE rather than guessing; the REFERENCE docs describe pro
vs free and can corroborate.
