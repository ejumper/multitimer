# PH1PART3 — Data Model Extraction

Part of [Phase 1](./OVERVIEW.md). [CONVENTIONS.md](./CONVENTIONS.md) binds this task.

## 1.0 Objective

Document the app's complete persistent data model: entities, fields, relationships,
storage (DB/tables, preferences), and any serialization formats (backup/export).
Later parts (and the eventual rebuild) treat this as the source of truth.

## 2.0 Prerequisites (STOP if unmet)

- `WORK/MAP.md`, `WORK/ISLANDS.md`, `WORK/APK-INFO.md` exist.
- Use MAP's "Where to look → data model" as your starting point list.

## 3.0 Procedure

1. **Locate persistence tech.** Run targeted searches (fetcher-friendly, bounded):
   - Room: `rg -l "@Entity|@Dao|RoomDatabase" <app-pkg-path>`
   - Raw SQLite: `rg -l "SQLiteOpenHelper|CREATE TABLE" <app-pkg-path>`
   - Preferences: `rg -n "getSharedPreferences|PreferenceManager" <app-pkg-path>`
   - Serialization: `rg -l "@SerializedName|Gson|Moshi" <app-pkg-path>`
2. **Entities.** For each entity/table: name, every field (name, type, default,
   meaning), relationships/foreign keys, indexes. Prefer schema-bearing sources
   (annotations, CREATE TABLE strings, migrations) over inferring from usage.
3. **DB metadata:** database name(s), schema version, migration history (each
   migration = what changed and when in version order).
4. **Preferences:** every key, type, default, and (from strings.xml / settings UI)
   the human-facing meaning. Keys alone are not meanings — link to string resources.
5. **Serializable models:** anything exported/backed-up — the exact JSON/XML shape.
6. Cross-check entity inventory against REFERENCE/index.md feature list: a feature
   with no backing entity is suspicious → note in GAPS (or it's preference-driven).

## 4.0 Deliverables

`FINDINGS/data-model.md` per CONVENTIONS format, containing at minimum:
- `## 1.0 Entities` (per-entity field tables)
- `## 2.0 Storage & migrations`
- `## 3.0 Preferences`
- `## 4.0 Serialization / backup formats`
- `## GAPS` / `## CONFIDENCE`

## 5.0 Self-Verification Checklist

- [ ] Every entity field has a cited source file+lines
- [ ] Migration list is version-ordered and complete (or gap noted)
- [ ] Every preference key discovered appears (count them)
- [ ] Cross-check against REFERENCE features done; discrepancies listed

## 6.0 Notes

- Expect the core entities to be something like boards/timers — DO NOT assume; read.
- If persistence is obfuscated beyond schema readability, fall back to: CREATE TABLE
  strings, `res/xml/` backups rules, and help docs — and rate confidence honestly.
