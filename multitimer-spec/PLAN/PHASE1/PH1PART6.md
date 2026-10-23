# PH1PART6 — UI Structure

Part of [Phase 1](./OVERVIEW.md). [CONVENTIONS.md](./CONVENTIONS.md) binds this task.

## 1.0 Objective

Document every screen of the app and its structure: screens, navigation between them,
each screen's layout composition, plus home-screen widgets and theming. Resource
files are the backbone here — they survive obfuscation, so this part is mostly rote.

## 2.0 Prerequisites (STOP if unmet)

- `WORK/MAP.md`, `WORK/ISLANDS.md`, `FINDINGS/data-model.md` (entity vocabulary).
- `REFERENCE-IMAGES/` contains user-provided app screenshots (iPhone captures of the
  iOS app — same conceptual UI; note platform differences may exist).

## 3.0 Procedure

0. **Index the screenshots.** View each file in `REFERENCE-IMAGES/` and write
   `REFERENCE-IMAGES/index.md`: filename → what screen/content it shows (1–2 lines
   each). Keep original filenames. These are ground truth for UI cross-checking; the
   index is what you re-read later (not the images) to save context.

1. **Screen inventory.** From apktool output:
   - `WORK/decompiled/apktool/res/layout/` — list layout files; activity layouts vs
     fragments vs item/row layouts vs dialogs (naming usually reveals role).
   - Navigation graphs if present: `res/navigation/*.xml` — extract the graph.
   - Map each screen to its activity/fragment class via `rg -n "R.layout\.<name>"`
     in jadx sources (fetcher task — bounded file lists).
2. **Per-screen structure.** For each real screen (not rows/dialogs): purpose (from
   REFERENCE), primary components (list/grid/pager/bottom-nav/fab), what entity it
   presents (data model link), and its navigation parents/children.
3. **Dialogs & item layouts:** inventory with one-line purposes (these encode
   interactions: edit-timer dialog, chain editor, etc.).
4. **Home-screen widgets:** `res/xml/*widget*` provider files + their layouts —
   what widgets exist, what they display.
5. **Theming & display modes:** themes/colors (dark mode support), font/size options
   from settings strings — one short section, don't rabbit-hole.
6. **Cross-check:** every screen in REFERENCE's feature walkthroughs appears in the
   inventory (or GAPS). Every distinct screen in `REFERENCE-IMAGES/index.md` appears
   in the screen map (or GAPS) — screenshots are ground truth.

## 4.0 Deliverables

`FINDINGS/ui-structure.md` per CONVENTIONS format:
- `## 1.0 Screen map` (table: screen → class → layout → purpose → nav parents/children)
- `## 2.0 Per-screen detail` (one subsection per screen)
- `## 3.0 Dialogs & item layouts`
- `## 4.0 Home-screen widgets`
- `## 5.0 Theming & display modes`
- `## GAPS` / `## CONFIDENCE`

## 5.0 Self-Verification Checklist

- [ ] Every layout file is classified (screen / row / dialog / widget / other)
- [ ] Navigation relationships cite the nav graph or code evidence
- [ ] Each screen's purpose cross-references REFERENCE where possible
- [ ] Widgets section is complete (or explicitly empty-with-evidence)

## 6.0 Notes

Describe STRUCTURE, not pixel design — component types and arrangement, not styling.
The eventual rebuild will restyle anyway; we need the information architecture.
