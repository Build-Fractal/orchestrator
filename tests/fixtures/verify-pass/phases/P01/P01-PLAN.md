---
phase: P01
milestone: M001
goal: "Set up extension foundation"
demo_sentence: "Developer can install the extension and see all commands registered"
risk: low
depends_on: []
---

## Must-Haves

### Truths
- extension.yml is valid YAML and contains command registrations
  - Check: `grep -q 'commands:' extension.yml`
- The manifest declares the orchestrator namespace
  - Check: `grep -q 'orchestrator' extension.yml`

### Artifacts
- extension.yml (min 5 lines, contains "commands:")
- scripts/setup.sh (min 3 lines)

### Key Links
- extension.yml → scripts/setup.sh (references setup script)

## Tasks

### T01: Create extension manifest
Create extension.yml with all commands.

## Files Likely Touched
- extension.yml
- scripts/setup.sh
