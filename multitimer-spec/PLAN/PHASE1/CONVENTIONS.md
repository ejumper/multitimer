# PHASE 1 Conventions — binds every PH1PART task

You are a qwen3.8-flash-next orchestrator executing one PH1PART task file. These rules override convenience. If your part file and this file conflict, ASK via BLOCKERS.md rather than guessing.

## 1.0 Sessions & Roles

- **Orchestrator (you):** plans, decides, writes deliverables. Runs one PH1PART file, start to finish, in this session.
- **Explorer (sub-session):** you may use explorer to spawn 1 subagent at a time to fetch information for you (decompiled code files, web pages, command output) This is purely for context preservation, if the answer is all you need, use this to keep the search for it out of you context.

## 2.0 Context Discipline

1. `rg --files` / `rg -l` (locate) before `rg` (search) before reading any file.
2. Never read a whole decompiled tree or a whole directory of files. Always have a specific file list first.
3. Read the smallest line-range that answers the question (`rg -n` gives you line numbers).
4. Your part file lists your allowed inputs. Raw material outside your part's scope is off-limits without a BLOCKERS.md note.
5. **Durability:** write findings incrementally. After every meaningful discovery, append to the deliverable file. Never hold unwritten knowledge in context.

## 3.0 Findings Format

Files in `FINDINGS/` (and `WORK/` maps) are the chaining medium — the ONLY thing later parts consume. Requirements:

- kebab-case filenames, markdown, numbered sections (`## 1.0 ...` style)
- Header block at top: part number, date, APK version (from `WORK/APK-INFO.md`)
- **Every factual claim cites its source**: decompiled file path (relative to `WORK/decompiled/jadx/` or `WORK/decompiled/apktool/`) + line range, or REFERENCE doc filename. Uncited claims are violations.
- Pro-tier features are marked **inline** as `**(PRO)**`
- `## GAPS` section: everything you could not determine, with what you tried
- `## CONFIDENCE` section: rate the doc overall High/Medium/Low + why

## 4.0 BLOCKERS.md Protocol

When stuck after 2–3 genuine attempts (not repeat-the-same-thing attempts):

1. Append to `PLAN/PHASE1/BLOCKERS.md`: part number, what you were doing, exact command/error or reasoning obstacle, what you expected, what you tried.
2. STOP the part. Do not guess, do not fabricate, do not "work around" silently.
3. Write your completion report noting the blocked step.

Fabricating a plausible answer is the worst possible failure mode. An honest gap costs one bullet point; a hallucinated "fact" poisons the SPEC.

## 5.0 Environment Facts

- Project root = this multitimer/ dir; NOT in Nextcloud sync; everything stays inside
- `java` (25), `rg`, `unzip` are installed. `jadx`/`apktool` get installed in Part 1.
- You have web access and the pi harness tools (including explore/execute subagents — the fetcher sub-session supersedes them for raw-material retrieval).
- Long commands (decompiles) may take minutes — run them with nohup + log file if output is unbounded (see harness guidance).

## 6.0 Deliverable Hygiene

- Deliverables go exactly where the part file says (exact filenames).
- Before declaring done: run the part's self-verification checklist literally, item by item, and say so in your completion report.
- Completion report format (in chat, not a file): what was produced, checklist results, gaps/anything suspicious, suggested tweak to any later part.

## 7.0 Technique Fallbacks

When a recon *technique* problem arises (as opposed to a project question), consult `REFERENCE/method/` (prefetched in Part 1) before doing free-form web searches:

- **jadx output broken for a class** → read the same class in apktool's smali (`WORK/decompiled/apktool/smali*/...`) — awkward but authoritative.
- **Obfuscated names make tracing hopeless** → re-anchor on things obfuscation can't touch: `res/values/strings.xml`, layout filenames, manifest components, DB schemas/preference keys.
- **Heavy obfuscation (per Part 2's rating) and you need logic** → a second jadx run with `--deobf` into `WORK/decompiled/jadx-deobf/` yields readable aliases. They are synthetic names: any citation must name which tree it came from. Only worth it for Parts 4–5.
- **Native libraries** → out of scope. Note existence in GAPS; do not attempt analysis.
- Method docs: MASTG-TECH-0014 (static analysis), AndroidAppRE chapters (fundamentals, DEX, obfuscation), httptoolkit workflow post. Their security/Frida/Ghidra material is not our goal — ignore it.
