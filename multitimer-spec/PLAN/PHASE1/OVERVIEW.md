# PHASE 1 — Decompile & Recon → Rebuild Spec

## 1.0 Goal

Turn the MultiTimer Android APK into a **written SPEC** that completely describes the app's behavior, data, and UI — sufficient to rebuild a faithful clone later without ever consulting the original app again. Phase 1 produces *knowledge*, not code.

Target app: **MultiTimer** by Sergey Astakhov (persapps), package `com.persapps.multitimer`,
official site multitimer.net, help center help.multitimer.net.

## 2.0 Scope Fence

**In scope:** APK acquisition, decompiling, surgical recon, help-doc cross-referencing, assembling the SPEC.

**Deferred — do not decide in phase 1:** framework/language choice, any implementation of the new app, sync mechanism *design* (we only document what the original does),
transplanting code (we extract a spec; we never copy code or assets).

## 3.0 Decisions Log (settled)

| # | Decision | Resolution |
| - | -------- | ---------- |
| D1 | App identity | `com.persapps.multitimer` (MultiTimer, persapps) — verify at Part 1 |
| D2 | APK source | User downloads (candidate: softpedia APK mirror) and drops in `./APK/`; Part 1 verifies package + version vs Play Store/help docs; main model assists user in confirming latest version |
| D3 | Working tree | Entire project dir is OUTSIDE Nextcloud sync (user removed it) — all work, including decompiled output, stays inside this dir |
| D4 | Pro tier | Pro features documented **inline**, marked `**(PRO)**`, never in a separate section |
| D5 | Reference docs | Pre-fetched into `./REFERENCE/` by Part 1 (also used as ground truth even though web access exists) |
| D6 | Execution model | One orchestrator session per PH1PART file; orchestrator may spawn ONE sub-session (fetcher) for raw material retrieval; both run qwen3.8-flash-next in the pi harness |
| D7 | Version pin | Analyze what the user downloads; Part 1 records versionName/versionCode/sha256; accept or re-fetch is a user checkpoint |

## 4.0 Directory Layout

```
multitimer/
├── APK/            # the APK snapshot(s); gitignore-able
├── PLAN/PHASE1/    # this plan: OVERVIEW, CONVENTIONS, PH1PART<N>.md
├── WORK/           # intermediate: decompiled trees, maps, APK-INFO.md
│   └── decompiled/{apktool,jadx}/
├── REFERENCE/      # pre-fetched help-center/website docs (ground truth) + RE method guides (method/)
├── REFERENCE-IMAGES/ # user-provided app screenshots; indexed in Part 6 (index.md)
├── FINDINGS/       # per-area recon findings; self-contained; the chaining medium
├── SPEC/           # final deliverable (assembled in Part 8)
└── BLOCKERS.md     # escalation log (see CONVENTIONS)
```

## 5.0 Part Breakdown & Dependencies

| Part | Title | Depends on | Checkpoint after? |
| ---- | ----- | ---------- | ----------------- |
| 1 | Setup, APK verification, reference prefetch | — | **YES — user confirms version acceptance** |
| 2 | Decompile + map + obfuscation assessment | 1 | **YES — parts 3–7 re-sized based on obfuscation report** |
| 3 | Data model extraction | 2 | no |
| 4 | Timer engine semantics | 3 | no (hardest part — read Part 4 before running) |
| 5 | Background operation & alert delivery | 3 | no |
| 6 | UI structure | 2, 3 | no |
| 7 | Settings, sounds, pro-gating, exclusions | 3 | no |
| 8 | Synthesis → SPEC/ | 3, 4, 5, 6, 7 | **YES — user reviews SPEC** |

Parts 3–7 are order-independent given their dependencies; if desired they can run in
any sequence, one at a time (two concurrent sessions max on this hardware).

## 6.0 Execution Model

- One fresh orchestrator session per `PH1PART<N>.md`. The orchestrator reads
  `CONVENTIONS.md` + its own part file + the part's input findings — nothing else
  from earlier sessions' context.
- The orchestrator may spawn **one** fetcher sub-session (same model) to retrieve and
  summarize raw material. Orchestrator context holds only summaries and citations.
- Findings are written **incrementally as work proceeds** — nothing important lives
  only in context (compaction-safe).
- Every part ends with deliverables written, self-verification checklist passed, and a
  STOP for the checkpoint (if flagged) or a short completion report.

## 7.0 Risks (live)

| Risk | Mitigation |
| ---- | ---------- |
| Obfuscation makes logic recon expensive | Part 2 rates it; checkpoint re-sizes parts 3–7; resources/manifest/DB survive obfuscation regardless |
| Kotlin coroutines decompile poorly | behavioral spec from observable code + strings + help docs; "mechanism unknown" is an acceptable gap entry |
| Flash executor wanders in huge trees | CONVENTIONS context-discipline rules; scoped input lists per part |
| Flash executor hits a hard knot | BLOCKERS.md protocol: document, stop, escalate |
| Softpedia APK not latest / repackaged | Part 1 verifies package name, records sha256; user decides accept/re-fetch; cross-check APKMirror as alternate source |
| Legal | personal-use recon; SPEC describes and never copies assets/sounds/code into future work |

## 8.0 Definition of Done (Phase 1)

1. `SPEC/` exists with README (index, method, pinned version), features, data-model,
   engine, ui, gaps docs
2. Every feature in REFERENCE appears in features.md or gaps.md
3. Every SPEC claim cites a findings doc; every findings doc cites source file paths
4. Gap list reviewed by user
