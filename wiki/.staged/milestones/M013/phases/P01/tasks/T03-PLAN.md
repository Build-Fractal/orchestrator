---
schema_version: "1.0"
type: task-plan
task: "T03"
phase: "P01"
milestone: "M013"
name: ".github/ISSUE_TEMPLATE/uat-bug.yml UAT Bug Issue Form + autocomplete-source pointer"
depends_on: []
---

## Prerequisites

- No upstream task dependencies.
- `.github/ISSUE_TEMPLATE/` does NOT yet exist in this repo (verified via Glob). This task creates the directory and the first template inside it.
- GitHub Issue Forms reference: <https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-issue-forms>
- The template's "Spec Chunk ID" field is a plain `input` (not a dropdown with dynamic autocomplete — GitHub Issue Forms do not support dynamic autocomplete via API at filing time). Autocomplete happens at the operator's text editor, driven by the Spec Chunks section T04 ships to `KNOWLEDGE-INDEX.md`. The template's job is to make the field required and to point the user at `KNOWLEDGE-INDEX.md` for chunk IDs.

## Description

Ship `.github/ISSUE_TEMPLATE/uat-bug.yml` — a GitHub Issue Forms template that stakeholders use to file UAT defects with a mandatory spec-chunk link. Plus a verifier that asserts the file parses as valid YAML, carries the required fields, and links to the autocomplete source.

Template structure (required):

- `name`: "UAT Bug"
- `description`: one-line gloss
- `title`: "[UAT] " prefix
- `labels`: `["uat-bug"]`
- `body`: form fields including a required `Spec Chunk ID` input, the defect description, steps to reproduce, expected vs. actual behavior, and environment info.

## Steps

### Step 1: Create `.github/ISSUE_TEMPLATE/uat-bug.yml`

```yaml
name: UAT Bug
description: Report a defect found during User Acceptance Testing against a specific spec chunk.
title: "[UAT] "
labels:
  - uat-bug
body:
  - type: markdown
    attributes:
      value: |
        Thanks for filing a UAT bug. This template captures the link back to the spec chunk whose acceptance criterion failed, so the orchestrator can route the defect into execution-error / spec-gap / spec-error triage buckets.

        **How to find your Spec Chunk ID**: open [KNOWLEDGE-INDEX.md](../../KNOWLEDGE-INDEX.md) at the repo root and scroll to the `## Spec Chunks` section. Chunk IDs look like `SPEC-US-001`, `SPEC-AC-007`, `SPEC-CON-003`. Copy the exact ID (no surrounding whitespace) into the field below.

  - type: input
    id: spec_chunk_id
    attributes:
      label: Spec Chunk ID
      description: "The ID of the spec chunk whose acceptance criterion failed (e.g. SPEC-US-001, SPEC-AC-007). Required — the ingestion step uses this to link the defect back to the owning phase and tests."
      placeholder: "SPEC-US-001"
    validations:
      required: true

  - type: textarea
    id: defect_description
    attributes:
      label: Defect description
      description: What went wrong? One or two sentences.
      placeholder: "Expected X, observed Y."
    validations:
      required: true

  - type: textarea
    id: steps_to_reproduce
    attributes:
      label: Steps to reproduce
      description: The minimum steps a maintainer can follow to observe the defect.
      placeholder: |
        1. Run `orchestrator:...`
        2. Observe that ...
    validations:
      required: true

  - type: textarea
    id: expected_vs_actual
    attributes:
      label: Expected vs. actual behavior
      description: Describe what the spec chunk's acceptance criterion expected and what actually happened.
    validations:
      required: true

  - type: input
    id: environment
    attributes:
      label: Environment
      description: "OS, runtime (Claude Code / Codex CLI / Cursor), orchestrator version."
      placeholder: "macOS 14.5, Claude Code, orchestrator v0.9.0"
    validations:
      required: false

  - type: markdown
    attributes:
      value: |
        ---

        _This issue will be ingested by `scripts/integrations/uat-ingest.sh` into `knowledge/spec/defect/SPEC-DEFECT-NNN.md` with graph edges to chunk → phase → tests. Unknown chunk IDs are flagged `chunk-lookup-failed` — never silently dropped._
```

### Step 2: Create `scripts/verify/m013-p01-uat-template.sh`

Assertions:
1. `.github/ISSUE_TEMPLATE/uat-bug.yml` exists.
2. Parses as valid YAML (prefer `python3 -c 'import yaml,sys;yaml.safe_load(open(sys.argv[1]))'`; fall back to `yq` if present; `SKIP:` if neither, following [M012](../../../../../milestones/M012/index.md) graceful-tool-absent pattern).
3. Required top-level keys present: `name`, `description`, `labels`, `body`.
4. `labels` contains `uat-bug` (string literal grep).
5. At least one form body block has `id: spec_chunk_id` (grep).
6. The spec-chunk input block carries `required: true` within ~5 lines after the `id: spec_chunk_id` line (grep with `-A 5`).
7. Template links to `KNOWLEDGE-INDEX.md` (substring match).

```bash
#!/usr/bin/env bash
# scripts/verify/m013-p01-uat-template.sh
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEMPLATE="${REPO_ROOT}/.github/ISSUE_TEMPLATE/uat-bug.yml"

fail_count=0
assert_ok() { if [ "$1" -eq 0 ]; then echo "PASS: $2"; else echo "FAIL: $2"; fail_count=$((fail_count + 1)); fi; }

[ -f "$TEMPLATE" ]; assert_ok $? "uat-bug.yml present"

# YAML parse (python3 preferred, yq fallback, else SKIP)
if command -v python3 >/dev/null 2>&1; then
  python3 -c "import yaml,sys; yaml.safe_load(open('$TEMPLATE'))" >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "PASS: template is valid YAML (python3)"
  else
    # python3 may lack PyYAML; emit SKIP on import error rather than FAIL
    python3 -c "import yaml" >/dev/null 2>&1
    if [ "$?" -ne 0 ]; then
      echo "SKIP: YAML validator (PyYAML not installed); gate passes"
    else
      echo "FAIL: template is not valid YAML"
      fail_count=$((fail_count + 1))
    fi
  fi
elif command -v yq >/dev/null 2>&1; then
  yq . "$TEMPLATE" >/dev/null 2>&1
  assert_ok $? "template is valid YAML (yq)"
else
  echo "SKIP: YAML validator (no python3 or yq); gate passes"
fi

# Required top-level keys
for key in name description labels body; do
  grep -qE "^${key}:" "$TEMPLATE"
  assert_ok $? "has top-level key: ${key}"
done

# labels contains uat-bug
grep -E "^[[:space:]]+-[[:space:]]+uat-bug[[:space:]]*\$" "$TEMPLATE" >/dev/null
assert_ok $? "labels list contains uat-bug"

# spec_chunk_id field with required: true nearby
grep -q "id: spec_chunk_id" "$TEMPLATE"; assert_ok $? "form has id: spec_chunk_id"
grep -A 10 "id: spec_chunk_id" "$TEMPLATE" | grep -q "required: true"
assert_ok $? "spec_chunk_id field is required"

# Link to KNOWLEDGE-INDEX.md
grep -q "KNOWLEDGE-INDEX.md" "$TEMPLATE"; assert_ok $? "links to KNOWLEDGE-INDEX.md"

if [ "$fail_count" -eq 0 ]; then
  echo "PASS: m013-p01-uat-template.sh"
  exit 0
fi
echo "FAIL: m013-p01-uat-template.sh ($fail_count failures)"
exit 1
```

## Must-Haves

- `.github/ISSUE_TEMPLATE/uat-bug.yml` is a valid GitHub Issue Form.
- `Spec Chunk ID` input has `validations.required: true`.
- Template points users at the repo-root `KNOWLEDGE-INDEX.md` for chunk-ID lookup.
- `labels` list contains `uat-bug`.
- Verifier passes all assertions.

## Verification

- `bash scripts/verify/m013-p01-uat-template.sh`

## Inputs

### From Disk (Pre-existing)

- None. This task is dependency-free from upstream P01 tasks. The template is a standalone GitHub Issue Form YAML.
- Note: the `KNOWLEDGE-INDEX.md` link in the template is a forward reference — T04 widens that file with a `## Spec Chunks` section. The template itself does not require T04 to have run; the link is a static markdown anchor that resolves once T04 ships.

## Constraints

- Bash 3.2 compatible (verifier script).
- No jq/yq/python3 hard dependency: YAML validation is best-effort with `SKIP:` on absent tool (graceful-absent-tool pattern from M012).
- YAML must use two-space indentation (GitHub Issue Forms convention); mixing tabs will parse-fail on GitHub's renderer.
- `title` prefix is `"[UAT] "` (with trailing space); the operator types the defect summary after the prefix.
- No dynamic chunk-ID autocomplete at the form level — GitHub Issue Forms does not support this. The `description` / `placeholder` fields point users at `KNOWLEDGE-INDEX.md`.
- Single-script-file shape (AD-19) for the verify gate; no compound bash chains.

## Expected Output

- `.github/ISSUE_TEMPLATE/uat-bug.yml` created.
- `scripts/verify/m013-p01-uat-template.sh` created.
- `bash scripts/verify/m013-p01-uat-template.sh` → `PASS: m013-p01-uat-template.sh`, exit 0.
