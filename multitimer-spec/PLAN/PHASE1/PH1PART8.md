# PH1PART8 — Synthesis: Assemble the SPEC

Part of [Phase 1](./OVERVIEW.md). [CONVENTIONS.md](./CONVENTIONS.md) binds this task.

## 1.0 Objective

Merge all findings + reference docs into the phase deliverable: `SPEC/` — a complete,
cited, gap-aware description of MultiTimer sufficient to rebuild it without the
original. This is a synthesis part: your inputs are FINDINGS and REFERENCE docs, NOT
raw decompiled code.

## 2.0 Prerequisites (STOP if unmet)

- All of: `FINDINGS/{data-model,engine,background-and-alerts,ui-structure,
  settings-sounds-pro,exclusions}.md` and `WORK/APK-INFO.md`.
  If any is missing, STOP and report which.

## 3.0 Procedure

1. **Read everything first.** Read every FINDINGS doc fully (they are your bounded
   input set — this is the one part where reading inputs wholesale is correct).
   Build a mental (scratchpad) list of contradictions and gaps.
2. **Resolve contradictions.** Findings may disagree (e.g. engine.md vs help docs on
   link delay). Resolve by weight of evidence: decompiled code > help docs > inference;
   where unresolvable, present both with sources in SPEC/gaps.md.
3. **Write the SPEC files.** Plain behavioral language aimed at a developer who has
   never seen the app. Cite findings docs (which carry the raw citations):
   - `SPEC/README.md` — index, method summary, pinned APK version/sha (from APK-INFO),
     confidence legend, how citations work
   - `SPEC/features.md` — complete feature inventory (pro marked inline `**(PRO)**`),
     organized by area, each feature 1–3 sentences + status (documented / partial / gap)
   - `SPEC/data-model.md` — entities, fields, relationships, preferences (condensed
     from findings; findings remain the deep reference)
   - `SPEC/engine.md` — timer types, state machine, zero-crossing, linking/sequencing,
     background behavior, alert delivery — THE core document, be thorough
   - `SPEC/ui.md` — screen map + per-screen structure summary
   - `SPEC/gaps.md` — everything unresolvable: item, why, what evidence exists,
     confidence level
4. **Completeness audit (the point of this part):**
   - Every REFERENCE/index.md feature → present in features.md or gaps.md
   - Every distinct screen in `REFERENCE-IMAGES/index.md` → present in ui.md or gaps.md
   - Every FINDINGS GAPS entry → present in gaps.md
   - Every features.md "documented" claim → backed by a findings citation
   Run this as a literal checklist and include the result in README.md.

## 4.0 Deliverables

`SPEC/` complete per the file list above.

## 5.0 Self-Verification Checklist

- [ ] All 6 SPEC files exist and render (check markdown links resolve)
- [ ] Completeness audit passed and recorded in README.md
- [ ] No uncited "documented" features; contradictions surfaced, not papered over
- [ ] Pro features marked inline throughout (no separate pro section)

## 6.0 STOP

**User checkpoint:** the phase ends with user review of SPEC/. Report: coverage
summary (# features documented/partial/gapped), biggest gaps, and your honest read on
whether the SPEC is buildable-from.
