# PH1PART2 — Decompile + Map + Obfuscation Assessment

Part of [Phase 1](./OVERVIEW.md). [CONVENTIONS.md](./CONVENTIONS.md) binds this task.

## 1.0 Objective

Fully decompile the APK with both tools and produce a **map**: what code exists, which
parts are the app vs third-party SDKs, how obfuscated it is, and where each recon area
(Parts 3–7) should look. This map is how later parts avoid wandering.

## 2.0 Prerequisites (STOP if unmet)

- `WORK/APK-INFO.md` exists (Part 1 done), tools installed per its instructions.

## 3.0 Procedure

### 3.1 Decompile

Input is the **base APK path recorded in `WORK/APK-INFO.md`** (may be
`WORK/xapk-extract/<...>.apk` if the app arrived as XAPK — not the XAPK itself).

1. `apktool d -f <base-apk> -o WORK/decompiled/apktool` (full decode: resources + smali)
2. `jadx -d WORK/decompiled/jadx --show-bad-code -j 4 <base-apk>` — expect some classes to
   error; capture the error summary in the map (a handful of failures is normal and fine).
3. If either tool takes very long, run under nohup with a log and poll.

### 3.2 Inventory (facts first — commands, not vibes)

1. File counts: `rg --files WORK/decompiled/jadx/sources | wc -l`, per top-level
   package: count of `.java` files under each `sources/<tld>/<org>/` dir.
2. Native libs: list `WORK/decompiled/apktool/lib/` (per-ABI `.so` names). If any
   non-trivial native lib exists, note it — logic there is out of reach of jadx.
3. Assets: list `assets/` (top level) and `res/raw/` (sounds usually live here — full
   filenames).
4. Manifest digest: from apktool manifest + jadx — every `activity`, `service`,
   `receiver`, `provider`, exported flags, intent filters, and the full permissions
   list, with the app's own classes clearly distinguished from library ones.

### 3.3 Classify code islands

Split every top-level package into exactly one of:
- **APP** — `com.persapps.*` and anything else that is clearly the app's own code
- **SDK** — with a label: android-x / kotlin+coroutines / google-ads / firebase /
  billing / crash-reporting / gson-or-moshi / room / other (name it)
Record as `WORK/ISLANDS.md`: package → classification → file count → role guess (1 line).

### 3.4 Obfuscation assessment (this decides how Parts 3–7 run)

Rate on evidence, in `WORK/MAP.md`:
1. Do APP classes have readable names? (sample ~10 across packages)
2. Do APP method/field names survive? (same sample)
3. Are resource names readable in `res/layout/`, `res/values/strings.xml`?
4. Are DB table/column names, preference keys, string constants readable in code?
Give a rating: **none / light / heavy**, with the sample evidence. Note what this
implies per recon area (e.g. "heavy → data model must come from schema files and
strings, not type names").

### 3.5 Recon targeting hints

Close the map with a "Where to look" section per upcoming part — concrete starting
paths/patterns for: data model (Part 3), engine (Part 4), background/alerts (Part 5),
UI (Part 6), settings/pro (Part 7). Use `rg -l` evidence, e.g. files containing
`RoomDatabase`, `ForegroundService`, `AlarmManager`, `R.layout`.

## 4.0 Deliverables

| File | Content |
| ---- | ------- |
| `WORK/MAP.md` | counts, native libs, assets list, manifest digest, obfuscation rating, where-to-look hints |
| `WORK/ISLANDS.md` | package classification table |

## 5.0 Self-Verification Checklist

- [ ] Both decompile trees exist and are populated (jadx sources > 1000 files expected)
- [ ] Every top-level package appears in ISLANDS.md exactly once
- [ ] Obfuscation rating cites ≥10 sampled class names
- [ ] "Where to look" section exists for Parts 3–7 with concrete paths/rg patterns

## 6.0 STOP

**User checkpoint:** the obfuscation rating may re-size Parts 3–7 (heavier → smaller,
narrower tasks). Report the rating and your recommendation before the next part runs.
