---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M003"
goal: "Establish adapter architecture, GSD2 reader, intermediate data format, source detection, and CLI entry point"
demo_sentence: "A developer can run the GSD2 adapter against a `.gsd/` directory and receive a normalized intermediate data structure containing knowledge entries, decisions, requirements, and milestone metadata extracted from `gsd.db` (or JSON fallback)."
risk: "high"
depends_on: []
---

## Must-Haves

### Truths

- The adapter interface defines a standard contract with detect, extract_knowledge, extract_decisions, extract_requirements, extract_milestones, and extract_telemetry functions
  - Check: `grep -q 'extract_knowledge\|extract_decisions\|extract_requirements\|extract_milestones\|extract_telemetry' scripts/migrate/adapter-interface.sh`
- Source detection auto-detects gsd2 (gsd.db present), gsd1 (.planning/ only), and speckit (.specify/ or specs/) source types
  - Check: `grep -q 'gsd2\|gsd1\|speckit' scripts/migrate/lib/detect-source.sh`
- The GSD2 adapter prefers SQLite (`gsd.db`) and falls back to JSON (`memories-snapshot.json`) when the database is unavailable
  - Check: `grep -q 'gsd\.db\|memories-snapshot\.json\|fallback\|sqlite3' scripts/migrate/adapters/gsd2.sh`
- The SQLite reader uses the `sqlite3` CLI only (no python3 or other database tools)
  - Check: `grep -q 'sqlite3' scripts/migrate/lib/sqlite-reader.sh && ! grep -q 'python3\|python ' scripts/migrate/lib/sqlite-reader.sh`
- JSON fallback parsing works without a `jq` hard dependency (uses grep/sed/awk, with jq as optional enhancement)
  - Check: `grep -qE 'command -v jq|which jq|type jq|JQ_AVAILABLE|_jq_available|has_jq' scripts/migrate/lib/json-fallback.sh`
- All scripts use `#!/usr/bin/env bash` shebang and `set -euo pipefail` for safety
  - Check: `for f in scripts/migrate/adapter-interface.sh scripts/migrate/adapters/gsd2.sh scripts/migrate/lib/sqlite-reader.sh scripts/migrate/lib/json-fallback.sh scripts/migrate/lib/detect-source.sh scripts/migrate/migrate.sh; do head -2 "$f" | grep -q 'bash' && head -5 "$f" | grep -q 'set -euo pipefail' || exit 1; done`
- The CLI entry point parses --source, --path, --recent-count, --merge, --force, and --abort flags
  - Check: `grep -q '\-\-source\|--path\|--recent-count\|--merge\|--force\|--abort' scripts/migrate/migrate.sh`
- The intermediate data format uses section markers that downstream transformers can parse with grep/sed
  - Check: `grep -qE '^\#\#\# (KNOWLEDGE|DECISIONS|REQUIREMENTS|MILESTONES|TELEMETRY)' scripts/migrate/adapter-interface.sh || grep -qE 'SECTION_KNOWLEDGE|SECTION_DECISIONS|SECTION_REQUIREMENTS|SECTION_MILESTONES|SECTION_TELEMETRY|section.*knowledge|section.*decisions' scripts/migrate/adapter-interface.sh`
- Source directories are never modified (read-only access enforced in adapter interface documentation and all adapter implementations)
  - Check: `grep -qi 'read.only\|never.*modif\|do not.*write\|non.destructive' scripts/migrate/adapter-interface.sh`
- Bash 3.2 compatibility: no associative arrays, no `|&` pipe operator, no `${var,,}` case conversion
  - Check: `! grep -n 'declare -A\||&\|${[a-zA-Z_]*,,}' scripts/migrate/adapters/gsd2.sh scripts/migrate/lib/sqlite-reader.sh scripts/migrate/lib/json-fallback.sh scripts/migrate/migrate.sh 2>/dev/null`

### Artifacts

- `scripts/migrate/adapter-interface.sh` (min 80 lines, contains "extract_knowledge")
- `scripts/migrate/adapters/gsd2.sh` (min 120 lines, contains "sqlite3")
- `scripts/migrate/lib/sqlite-reader.sh` (min 60 lines, contains "sqlite3")
- `scripts/migrate/lib/json-fallback.sh` (min 60 lines, contains "memories-snapshot")
- `scripts/migrate/lib/detect-source.sh` (min 30 lines, contains "detect_source")
- `scripts/migrate/migrate.sh` (min 80 lines, contains "--source")

### Key Links

- `scripts/migrate/adapters/gsd2.sh` -> `scripts/migrate/adapter-interface.sh` (adapter sources the interface)
- `scripts/migrate/adapters/gsd2.sh` -> `scripts/migrate/lib/sqlite-reader.sh` (adapter uses SQLite reader)
- `scripts/migrate/adapters/gsd2.sh` -> `scripts/migrate/lib/json-fallback.sh` (adapter uses JSON fallback)
- `scripts/migrate/migrate.sh` -> `scripts/migrate/lib/detect-source.sh` (CLI uses source detection)
- `scripts/migrate/migrate.sh` -> `scripts/migrate/adapter-interface.sh` (CLI sources adapter interface)

## Tasks

### T01: Adapter Interface Contract & Intermediate Data Format

Define the adapter interface that all source adapters must implement, and specify the intermediate data format that adapters produce and transformers consume.

### T02: SQLite Reader Library

Build the SQLite query helper library that the GSD2 adapter uses to read from `gsd.db` tables.

### T03: JSON Fallback Reader Library

Build the JSON/filesystem fallback reader for when `gsd.db` is unavailable.

### T04: GSD2 Adapter Implementation

Implement the GSD2 adapter that orchestrates SQLite-preferred, JSON-fallback data extraction using the adapter interface contract.

### T05: Source Detection & CLI Entry Point

Build the source detection script and the migration CLI entry point that parses flags and orchestrates the pipeline.

## Task Dependencies

T01 -> T02
T01 -> T03
T02 + T03 -> T04
T01 -> T05
T04 -> T05 (CLI must reference adapter to invoke)

Linear critical path: T01 -> T02 -> T04 -> T05
Parallel opportunity: T02 and T03 can run in parallel after T01

## Files Likely Touched

- `scripts/migrate/adapter-interface.sh` (create)
- `scripts/migrate/adapters/gsd2.sh` (create)
- `scripts/migrate/lib/sqlite-reader.sh` (create)
- `scripts/migrate/lib/json-fallback.sh` (create)
- `scripts/migrate/lib/detect-source.sh` (create)
- `scripts/migrate/migrate.sh` (create)
