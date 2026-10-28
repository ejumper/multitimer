# KICKOFF — per-part session prompt (v1 build)

Reusable prompt for pointing an executor model at a part. Replace `<N>` and drop the executor into the repo root: `~/HalfaCloud/Jumperpedia/Projects/Repos/multitimer`.

---

You are building **Planner** (working title), a Linux desktop interval-timer app. You are executing **Part <N>** of the v1 build plan.

Read, in order, before writing anything:
1. `new-app/v1/PLAN/CONVENTIONS.md` — binding rules (terminology, layer rules, TDD, git, blockers)
2. `new-app/v1/PLAN/OVERVIEW.md` — plan map, out-of-scope list
3. `new-app/v1/OUTLINE.md` — locked decisions D1–D13
4. Your part file: `new-app/v1/PLAN/P<N>.md` — the contract for this session
5. Anything the part file lists under "Read-first"

Rules of the session:
- Do exactly the part's scope — no more, no less. Out-of-scope guards in OVERVIEW.md §out-of-scope are hard boundaries.
- TDD: tests first where the part demands it. A part without green tests is not done.
- Stop and write `new-app/v1/PLAN/BLOCKERS.md` per CONVENTIONS §5 rather than improvising architecture.
- Work on branch `part/P<N>`; squash-merge with message `v1 P<N>: <title>` when the part's Definition of Done passes.
- End by appending the completion report (CONVENTIONS §6) to your part file.
