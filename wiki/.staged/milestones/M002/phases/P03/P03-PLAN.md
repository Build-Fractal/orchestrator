---
schema_version: "1.0"
type: phase-plan
phase: "P03"
milestone: "M002"
goal: "Deliver graph traversal and entry resolution so the context builder can follow relates_to links and inline selected detail files into dispatch payloads."
demo_sentence: "When the context builder includes a knowledge entry, it traverses the entry's relates_to links up to 1 hop (max 5 entries), handles cycles safely, and resolve-entries.sh reads selected detail files for payload injection."
risk: "medium"
depends_on: [P01, P02]
---

## Must-Haves

### Truths

- traverse-graph.sh reads the `relates_to` field from a detail file's YAML frontmatter and outputs related entry IDs
  - Check: `bash scripts/verify/m002-p03-traverse-reads-relates.sh`
- traverse-graph.sh limits output to a configurable max (default 5 entries)
  - Check: `bash scripts/verify/m002-p03-traverse-max-cap.sh`
- traverse-graph.sh is cycle-safe — visiting A that relates to B that relates back to A outputs each entry at most once
  - Check: `bash scripts/verify/m002-p03-traverse-cycle-safe.sh`
- traverse-graph.sh traverses exactly 1 hop by default (does not follow relates_to of related entries)
  - Check: `bash scripts/verify/m002-p03-traverse-one-hop.sh`
- traverse-graph.sh handles entries with no relates_to field gracefully (empty output, exit 0)
  - Check: `bash scripts/verify/m002-p03-traverse-no-relates.sh`
- resolve-entries.sh accepts a list of entry IDs and outputs their detail file content
  - Check: `bash scripts/verify/m002-p03-resolve-outputs-content.sh`
- resolve-entries.sh skips missing entries with a warning to stderr (does not fail)
  - Check: `bash scripts/verify/m002-p03-resolve-skips-missing.sh`
- resolve-entries.sh preserves entry IDs in output for traceability (FR-111)
  - Check: `bash scripts/verify/m002-p03-resolve-preserves-ids.sh`

### Artifacts

- scripts/knowledge/traverse-graph.sh (min 40 lines, contains "relates_to")
- scripts/knowledge/resolve-entries.sh (min 30 lines, contains "find_detail_file")
- scripts/verify/m002-p03-traverse-reads-relates.sh (min 15 lines, contains "PASS")
- scripts/verify/m002-p03-traverse-max-cap.sh (min 15 lines, contains "PASS")
- scripts/verify/m002-p03-traverse-cycle-safe.sh (min 15 lines, contains "PASS")
- scripts/verify/m002-p03-traverse-one-hop.sh (min 15 lines, contains "PASS")
- scripts/verify/m002-p03-traverse-no-relates.sh (min 15 lines, contains "PASS")
- scripts/verify/m002-p03-resolve-outputs-content.sh (min 15 lines, contains "PASS")
- scripts/verify/m002-p03-resolve-skips-missing.sh (min 15 lines, contains "PASS")
- scripts/verify/m002-p03-resolve-preserves-ids.sh (min 15 lines, contains "PASS")

### Key Links

- scripts/knowledge/traverse-graph.sh → scripts/knowledge/lib/detail-utils.sh (sources for find_detail_file, fm_field)
- scripts/knowledge/traverse-graph.sh → scripts/knowledge/lib/index-utils.sh (sources for get_project_root)
- scripts/knowledge/resolve-entries.sh → scripts/knowledge/lib/detail-utils.sh (sources for find_detail_file)
- scripts/knowledge/resolve-entries.sh → scripts/knowledge/lib/index-utils.sh (sources for get_project_root)

## Tasks

### T01: Create verification scripts for P03 must-haves

Create all 8 verification scripts under `scripts/verify/m002-p03-*.sh`. Each script sets up a temp directory with test fixtures (detail files, index), runs the script under test, and asserts expected output. Scripts must be self-contained, using PROJECT_ROOT override for isolation.

### T02: Implement traverse-graph.sh — knowledge graph traversal

Create `scripts/knowledge/traverse-graph.sh` that reads an entry's `relates_to` frontmatter field, resolves those IDs to confirm they exist as warm detail files, and outputs the related entry IDs. Supports 1-hop traversal (default), max 5 entries cap, and cycle-safe visited set.

### T03: Implement resolve-entries.sh — detail file content resolver

Create `scripts/knowledge/resolve-entries.sh` that accepts entry IDs (as arguments or on stdin), locates their detail files via `find_detail_file`, and outputs the file content with entry ID headers for traceability. Skips missing entries with stderr warnings.

## Task Dependencies

T01 → T02 → T03

T01 creates verification scripts first (they will initially fail). T02 implements traverse-graph.sh (satisfies graph-related verifications). T03 implements resolve-entries.sh (satisfies resolution-related verifications).

## Files Likely Touched

- scripts/knowledge/traverse-graph.sh (create)
- scripts/knowledge/resolve-entries.sh (create)
- scripts/verify/m002-p03-traverse-reads-relates.sh (create)
- scripts/verify/m002-p03-traverse-max-cap.sh (create)
- scripts/verify/m002-p03-traverse-cycle-safe.sh (create)
- scripts/verify/m002-p03-traverse-one-hop.sh (create)
- scripts/verify/m002-p03-traverse-no-relates.sh (create)
- scripts/verify/m002-p03-resolve-outputs-content.sh (create)
- scripts/verify/m002-p03-resolve-skips-missing.sh (create)
- scripts/verify/m002-p03-resolve-preserves-ids.sh (create)
