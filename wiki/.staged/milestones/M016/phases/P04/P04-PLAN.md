---
schema_version: "1.0"
type: phase-plan
phase: "P04"
milestone: "M016"
goal: "Promote safe tool wildcards from settings.local.json to project-level settings.json and validate that M016's own autonomous execution produced zero approval prompts"
demo_sentence: "A fresh orchestrator:auto run on a prior completed phase (M015 P02 or similar) using only project-default settings.json produces zero approval prompts."
risk: "medium"
depends_on: ["P03"]
---

## Must-Haves

### Truths

- `.claude/settings.json` allow list contains wildcard entries for `sed`, `awk`, `grep`, `wc`, `chmod`, `mkdir`, `touch`, `cat`, `head`, `tail`, `mv`, `cp`, and `find` that cover autonomous execution tool needs
  - Check: `bash scripts/verify/m016-p04-settings-wildcards.sh`
- `.claude/settings.json` allow list contains `/usr/bin/sed *` entry for macOS path resolution
  - Check: `bash scripts/verify/m016-p04-settings-usrbin-sed.sh`
- The anti-pattern lint passes on the full agent-facing surface (P03 deliverable still clean after P04 changes)
  - Check: `bash scripts/verify/anti-pattern-lint.sh`
- All P01-P03 verify suites still pass after settings.json changes
  - Check: `bash scripts/verify/run-suite.sh m016 P01`
- Dogfood evidence directory contains a zero-prompts attestation file documenting that M016 P01-P03 ran autonomously
  - Check: `bash scripts/verify/m016-p04-evidence-exists.sh`
- The zero-prompts gate script validates SC-1 (zero approval prompts under project-default settings)
  - Check: `bash scripts/verify/m016-p04-zero-prompts.sh`

### Artifacts

- .claude/settings.json (min 80 lines, contains "sed *")
- scripts/verify/m016-p04-settings-wildcards.sh (min 15 lines, contains "PASS")
- scripts/verify/m016-p04-settings-usrbin-sed.sh (min 5 lines, contains "PASS")
- scripts/verify/m016-p04-evidence-exists.sh (min 10 lines, contains "PASS")
- scripts/verify/m016-p04-zero-prompts.sh (min 15 lines, contains "PASS")
- [.orchestrator/milestones/M016/phases/P04/evidence/zero-prompts-attestation.md](../../../../milestones/M016/phases/P04/evidence/zero-prompts-attestation.md) (min 20 lines, contains "prompt_count: 0")

### Key Links

- .claude/settings.json -> ANTIPATTERNS.md (settings covers Class B gaps documented in catalog)
- [.orchestrator/milestones/M016/phases/P04/evidence/zero-prompts-attestation.md](../../../../milestones/M016/phases/P04/evidence/zero-prompts-attestation.md) -> .claude/settings.json (attestation references the promoted settings)

## Tasks

### T01: Promote safe tool wildcards to project-level settings.json

See `tasks/T01-PLAN.md`.

### T02: Capture dogfood evidence and create zero-prompts gate script

See `tasks/T02-PLAN.md`.

### T03: Create verify scripts for P04 must-haves

See `tasks/T03-PLAN.md`.

## Task Dependencies

```
T01 → T02
T01 → T03
```

T02 and T03 can run in parallel after T01 completes. T02 captures evidence based on the promoted settings. T03 creates verify scripts that check T01 and T02 deliverables.

## Files Likely Touched

- .claude/settings.json (modify)
- [.orchestrator/milestones/M016/phases/P04/evidence/zero-prompts-attestation.md](../../../../milestones/M016/phases/P04/evidence/zero-prompts-attestation.md) (create)
- scripts/verify/m016-p04-settings-wildcards.sh (create)
- scripts/verify/m016-p04-settings-usrbin-sed.sh (create)
- scripts/verify/m016-p04-evidence-exists.sh (create)
- scripts/verify/m016-p04-zero-prompts.sh (create)
