---
schema_version: "1.0"
type: phase-plan
phase: "P02"
milestone: "M003"
goal: "Transform intermediate knowledge data from GSD2 extraction into individual orchestrator detail files with YAML frontmatter, a complete KNOWLEDGE-INDEX.md, correct category mapping, supersession chain resolution, and scope tag derivation"
demo_sentence: "A developer can run the knowledge migrator against GSD2 intermediate data and find individual knowledge/{category}/{MEM###}.md detail files with full frontmatter, a complete KNOWLEDGE-INDEX.md, superseded entries archived in knowledge/archive/{category}/, and scope tags derived from source unit IDs."
risk: "high"
depends_on: ["P01"]
---

## Must-Haves

### Truths

- category-mapper.sh maps GSD2 categories (gotcha, convention, pattern, infrastructure, global-rule) to orchestrator categories (direct 1:1 mapping per spec US3)
  - Check: `grep -qE 'gotcha|convention|pattern|infrastructure|global-rule' scripts/migrate/lib/category-mapper.sh`
- scope-tag.sh derives orchestrator scope tags from GSD2 source_unit_id: M008/S02 becomes [milestone:[M008](../../../../milestones/M008/index.md)]
  - Check: `grep -qE '\[milestone:' scripts/migrate/lib/scope-tag.sh`
- supersession-chain.sh resolves supersession chains from intermediate data and classifies entries as active or superseded
  - Check: `grep -qE 'supersed|active|chain' scripts/migrate/lib/supersession-chain.sh`
- knowledge.sh transform reads knowledge.dat TSV, produces individual detail files in knowledge/{category}/{MEM###}.md with correct YAML frontmatter
  - Check: `grep -qE 'knowledge\.dat\|knowledge/' scripts/migrate/transform/knowledge.sh`
- knowledge.sh writes superseded entries to knowledge/archive/ with superseded_by pointers preserved
  - Check: `grep -qE 'knowledge/archive' scripts/migrate/transform/knowledge.sh`
- knowledge.sh preserves source entry IDs (MEM042 stays MEM042) per AD-5
  - Check: `grep -qE 'id.*MEM\|preserve.*id\|ID.*preserv' scripts/migrate/transform/knowledge.sh`
- knowledge-index.sh generates KNOWLEDGE-INDEX.md from the migrated detail files (reuses rebuild-index.sh or reimplements the same logic)
  - Check: `grep -qE 'KNOWLEDGE-INDEX\|rebuild-index' scripts/migrate/transform/knowledge-index.sh`
- The intermediate format is extended to carry full GSD2 knowledge fields (confidence, hit_count, created_at, updated_at, superseded_by) via enhanced KNOWLEDGE_FIELDS
  - Check: `grep -qE 'confidence.*hit_count\|hit_count.*confidence' scripts/migrate/adapter-interface.sh`
- All scripts are Bash 3.2 compatible
  - Check: `! grep -rE 'declare -A|readarray|mapfile' scripts/migrate/transform/knowledge.sh scripts/migrate/transform/knowledge-index.sh scripts/migrate/lib/category-mapper.sh scripts/migrate/lib/supersession-chain.sh scripts/migrate/lib/scope-tag.sh`
- Source directories are never modified (transforms only read .dat files from output_dir)
  - Check: `grep -qiE 'read.only\|output_dir\|outdir' scripts/migrate/transform/knowledge.sh`

### Artifacts

- scripts/migrate/lib/category-mapper.sh (min 20 lines, contains "category")
- scripts/migrate/lib/scope-tag.sh (min 20 lines, contains "scope")
- scripts/migrate/lib/supersession-chain.sh (min 40 lines, contains "supersed")
- scripts/migrate/transform/knowledge.sh (min 100 lines, contains "knowledge.dat")
- scripts/migrate/transform/knowledge-index.sh (min 30 lines, contains "KNOWLEDGE-INDEX")

### Key Links

- scripts/migrate/transform/knowledge.sh -> scripts/migrate/adapter-interface.sh (sources field definitions)
- scripts/migrate/transform/knowledge.sh -> scripts/migrate/lib/category-mapper.sh (category mapping)
- scripts/migrate/transform/knowledge.sh -> scripts/migrate/lib/scope-tag.sh (scope tag derivation)
- scripts/migrate/transform/knowledge.sh -> scripts/migrate/lib/supersession-chain.sh (chain resolution)
- scripts/migrate/transform/knowledge-index.sh -> scripts/knowledge/rebuild-index.sh (reuses index build logic)

## Tasks

### T01: Extend Intermediate Format and Library Scripts

Extend KNOWLEDGE_FIELDS in adapter-interface.sh to include confidence, hit_count, created_at, updated_at, superseded_by. Update sqlite_read_knowledge in sqlite-reader.sh to extract these additional fields. Update json_read_knowledge in json-fallback.sh similarly. Create category-mapper.sh and scope-tag.sh library scripts.

### T02: supersession-chain.sh — Chain Resolution

Build a library script that reads knowledge.dat, traces supersession chains (entry A superseded by B, B superseded by C), and produces two lists: active entries and superseded entries with their final superseded_by pointers.

### T03: knowledge.sh — Main Knowledge Transform

Build the main transform script that reads knowledge.dat, resolves supersession chains, maps categories, derives scope tags, and writes individual detail files to knowledge/{category}/{MEM###}.md (active) or knowledge/archive/{category}/{MEM###}.md (superseded).

### T04: knowledge-index.sh — Index Generation

Build a script that generates KNOWLEDGE-INDEX.md from the migrated detail files. Can delegate to rebuild-index.sh if the target project root is set correctly via PROJECT_ROOT.

### T05: End-to-End Verification Against Real Data

Test the full pipeline: extract GSD2 knowledge → transform → detail files + index. Verify against lakeledger's actual .gsd/ data (128 active, 24 superseded entries).

## Task Dependencies

T01 -> T02 (chain resolution needs extended fields)
T01 -> T03 (transform needs extended fields and lib scripts)
T02 -> T03 (transform uses chain resolution)
T03 -> T04 (index built from detail files)
T04 -> T05 (verification needs all components)

Critical path: T01 -> T02 -> T03 -> T04 -> T05

## Files Likely Touched

- scripts/migrate/adapter-interface.sh (modify — extend KNOWLEDGE_FIELDS)
- scripts/migrate/lib/sqlite-reader.sh (modify — extend knowledge query)
- scripts/migrate/lib/json-fallback.sh (modify — extend knowledge extraction)
- scripts/migrate/lib/category-mapper.sh (create)
- scripts/migrate/lib/scope-tag.sh (create)
- scripts/migrate/lib/supersession-chain.sh (create)
- scripts/migrate/transform/knowledge.sh (create)
- scripts/migrate/transform/knowledge-index.sh (create)
