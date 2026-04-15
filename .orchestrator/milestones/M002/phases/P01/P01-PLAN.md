---
schema_version: "1.0"
type: phase-plan
phase: "P01"
milestone: "M002"
goal: "Establish the three-temperature knowledge storage foundation with individual detail files, a pipe-delimited index, and CRUD shell scripts"
demo_sentence: "A developer can create individual knowledge detail files under knowledge/{category}/, each with YAML frontmatter, and the system builds a pipe-delimited KNOWLEDGE-INDEX.md that is scannable with grep/awk and rebuildable from disk."
risk: "high"
depends_on: []
---

## Must-Haves

### Truths

- create-entry.sh produces a detail file with YAML frontmatter containing id, category, confidence, hit_count, created_at, last_verified, source_unit, supersedes, superseded_by, relates_to fields
  - Check: `grep -qE '^id:' knowledge/convention/MEM001.md 2>/dev/null || bash scripts/knowledge/create-entry.sh --id MEM001 --category convention --confidence 0.90 --scope-tags "[project]" --source-unit "M002/P01" --source-type execution --description "Test entry" --body "Test body content" && grep -qE '^id:' knowledge/convention/MEM001.md`
- create-entry.sh atomically updates KNOWLEDGE-INDEX.md when creating an entry (writes to temp file, then mv)
  - Check: `grep -qE 'mv.*tmp.*INDEX\|mv.*KNOWLEDGE-INDEX' scripts/knowledge/create-entry.sh`
- rebuild-index.sh regenerates KNOWLEDGE-INDEX.md by scanning all detail files in knowledge/
  - Check: `grep -qE 'knowledge/.*\*/.*\.md\|find.*knowledge' scripts/knowledge/rebuild-index.sh`
- update-entry.sh can modify confidence, last_verified, and hit_count on an existing entry
  - Check: `grep -qE 'confidence|last_verified|hit_count' scripts/knowledge/update-entry.sh`
- supersede-entry.sh marks an old entry with superseded_by and removes it from the index
  - Check: `grep -qE 'superseded_by' scripts/knowledge/supersede-entry.sh`
- archive-entry.sh moves an entry to knowledge/archive/ and removes it from the index
  - Check: `grep -qE 'knowledge/archive' scripts/knowledge/archive-entry.sh`
- promote-entry.sh moves an entry from knowledge/archive/ back to warm storage and updates the index
  - Check: `grep -qE 'archive.*knowledge/\|knowledge/.*archive' scripts/knowledge/promote-entry.sh`
- All scripts are Bash 3.2 compatible (no associative arrays, no readarray, no mapfile)
  - Check: `! grep -rE 'declare -A|readarray|mapfile' scripts/knowledge/`
- scope-filter.sh can filter KNOWLEDGE-INDEX.md by scope tag, category, and confidence threshold using grep/awk
  - Check: `grep -qE 'KNOWLEDGE-INDEX\|index' scripts/dispatch/scope-filter.sh && grep -qE 'grep\|awk' scripts/dispatch/scope-filter.sh`
- The staleness decay helper computes effective_confidence = confidence * max(0.5, 1.0 - (days_since_verified / 180))
  - Check: `grep -qE '180\|decay\|staleness\|effective_confidence' scripts/knowledge/lib/staleness.sh`
- All index writes use the atomic temp-file-then-mv pattern
  - Check: `grep -rqE 'mv.*tmp.*INDEX\|mv.*KNOWLEDGE-INDEX' scripts/knowledge/`
- All operations are idempotent (creating an existing entry is a no-op, archiving an already-archived entry is a no-op)
  - Check: `grep -qE 'already exists\|already archived\|idempotent\|no-op\|skip' scripts/knowledge/create-entry.sh && grep -qE 'already.*archive\|not found\|skip\|no-op' scripts/knowledge/archive-entry.sh`

### Artifacts

- knowledge/.gitkeep (min 0 lines, contains "")
- knowledge/archive/.gitkeep (min 0 lines, contains "")
- scripts/knowledge/create-entry.sh (min 80 lines, contains "set -euo pipefail")
- scripts/knowledge/update-entry.sh (min 50 lines, contains "set -euo pipefail")
- scripts/knowledge/supersede-entry.sh (min 60 lines, contains "superseded_by")
- scripts/knowledge/archive-entry.sh (min 50 lines, contains "knowledge/archive")
- scripts/knowledge/promote-entry.sh (min 50 lines, contains "knowledge/archive")
- scripts/knowledge/rebuild-index.sh (min 60 lines, contains "KNOWLEDGE-INDEX")
- scripts/knowledge/lib/staleness.sh (min 20 lines, contains "effective_confidence")
- scripts/dispatch/scope-filter.sh (min 100 lines, contains "KNOWLEDGE-INDEX")

### Key Links

- scripts/knowledge/create-entry.sh → KNOWLEDGE-INDEX.md (index update on create)
- scripts/knowledge/rebuild-index.sh → KNOWLEDGE-INDEX.md (full index rebuild)
- scripts/knowledge/archive-entry.sh → knowledge/archive/ (cold storage target)
- scripts/knowledge/promote-entry.sh → knowledge/archive/ (cold storage source)
- scripts/knowledge/supersede-entry.sh → KNOWLEDGE-INDEX.md (index removal on supersede)
- scripts/dispatch/scope-filter.sh → KNOWLEDGE-INDEX.md (index-based filtering)

## Tasks

### T01: Directory Structure and Shared Library

Create the knowledge directory tree, the staleness decay helper library, and the KNOWLEDGE-INDEX.md header format.

### T02: create-entry.sh and rebuild-index.sh

Implement the two foundational scripts: creating individual knowledge detail files with YAML frontmatter and building/rebuilding the pipe-delimited index.

### T03: update-entry.sh and supersede-entry.sh

Implement confidence/metadata updates and entry supersession with index synchronization.

### T04: archive-entry.sh and promote-entry.sh

Implement cold storage operations: archiving entries to knowledge/archive/ and promoting them back to warm storage.

### T05: scope-filter.sh Integration and End-to-End Verification

Update scope-filter.sh to work with the new index-based format, verify all scripts work together end-to-end.

## Task Dependencies

T01 → T02 → T03 → T04 → T05

T01 creates the directory structure and shared library that T02 needs. T02 creates the detail file format and index that T03/T04 operate on. T03 and T04 could theoretically run in parallel but are ordered sequentially for simplicity (T03's supersede logic is needed context for T04's archive logic). T05 integrates everything and verifies end-to-end.

## Files Likely Touched

- knowledge/.gitkeep (create)
- knowledge/archive/.gitkeep (create)
- scripts/knowledge/lib/staleness.sh (create)
- scripts/knowledge/lib/index-utils.sh (create)
- scripts/knowledge/create-entry.sh (create — replaces existing append-knowledge.sh interface)
- scripts/knowledge/update-entry.sh (create)
- scripts/knowledge/supersede-entry.sh (create)
- scripts/knowledge/archive-entry.sh (create)
- scripts/knowledge/promote-entry.sh (create)
- scripts/knowledge/rebuild-index.sh (create)
- scripts/dispatch/scope-filter.sh (modify — add index-based filtering mode)
- KNOWLEDGE-INDEX.md (create — generated artifact)
