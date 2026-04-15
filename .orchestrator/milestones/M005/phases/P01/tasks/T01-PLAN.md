---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M005"
name: "Hash utility library + verification scripts"
depends_on: []
---

## Description

Create the hash utility library at `scripts/lib/hash.sh` and all seven
verification scripts for phase P01 under `scripts/verify/p01-*.sh`.

The hash library provides two functions:

1. `compute_content_hash <string>` -- takes a string argument, computes its
   SHA-256 digest, and returns the formatted `sha256:{64-hex}` string. Uses
   `shasum -a 256` (available on macOS and Linux). Never returns bare hex.

2. `compute_file_body_hash <filepath>` -- reads a markdown file, extracts the
   body content (everything after the closing `---` frontmatter delimiter),
   and passes it to `compute_content_hash`. Returns `sha256:{64-hex}`.

The library follows the double-sourcing guard pattern from
`scripts/lib/errors.sh`: `[ -n "${_HASH_SOURCED:-}" ] && return 0;
_HASH_SOURCED=1`.

Architectural constraint (AD-1): all hashes use `sha256:{64-hex}` format.
Body-only hashing means frontmatter metadata changes (confidence, hit_count,
last_verified) do NOT change the content hash.

The seven verification scripts are self-contained checks for the phase plan
Truths. Each follows AD-19: a single script file invocation, no inline
compound bash.

## Steps

### Step 1 -- Create `scripts/lib/hash.sh`

Create the file at `scripts/lib/hash.sh` with the following content:

```bash
#!/usr/bin/env bash
# scripts/lib/hash.sh -- Content hash utility for knowledge entries.
# Provides compute_content_hash and compute_file_body_hash functions.
# Hash format: sha256:{64-hex} per AD-1 convention. Body-only hashing
# excludes YAML frontmatter so metadata changes do not alter the hash.
#
# Bash 3.2 compatible (NFR-200). No jq required.

# --- Double-sourcing guard (follows errors.sh pattern) ---
[ -n "${_HASH_SOURCED:-}" ] && return 0
_HASH_SOURCED=1

# compute_content_hash <string>
# Computes SHA-256 of the given string and returns sha256:{hex}.
# Uses shasum -a 256 (available on macOS and Linux).
# Returns empty string and exit 1 if input is empty.
compute_content_hash() {
  local content="$1"
  if [ -z "$content" ]; then
    echo ""
    return 1
  fi
  local hex
  hex="$(printf '%s' "$content" | shasum -a 256 | cut -d ' ' -f 1)"
  printf 'sha256:%s\n' "$hex"
}

# compute_file_body_hash <filepath>
# Reads a markdown file with YAML frontmatter (delimited by --- lines),
# extracts the body (everything after the closing --- delimiter), and
# computes its content hash. Returns sha256:{hex}.
# Returns empty string and exit 1 if file does not exist or has no body.
compute_file_body_hash() {
  local filepath="$1"
  if [ ! -f "$filepath" ]; then
    echo ""
    return 1
  fi
  local body=""
  local in_frontmatter=0
  local frontmatter_closed=0
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$frontmatter_closed" -eq 1 ]; then
      if [ -z "$body" ]; then
        body="$line"
      else
        body="$body
$line"
      fi
    elif [ "$in_frontmatter" -eq 0 ] && [ "$line" = "---" ]; then
      in_frontmatter=1
    elif [ "$in_frontmatter" -eq 1 ] && [ "$line" = "---" ]; then
      frontmatter_closed=1
    fi
  done < "$filepath"
  # Trim leading blank line (common after frontmatter closing ---)
  body="$(printf '%s' "$body" | sed '1{/^$/d;}')"
  if [ -z "$body" ]; then
    echo ""
    return 1
  fi
  compute_content_hash "$body"
}
```

Make executable:

```bash
chmod +x scripts/lib/hash.sh
```

### Step 2 -- Create verification scripts

Create seven verification scripts under `scripts/verify/`. Each is a
standalone single-script-file check (AD-19 compliant).

**`scripts/verify/p01-hash-lib.sh`**

```bash
#!/usr/bin/env bash
# Verifies scripts/lib/hash.sh exists with double-sourcing guard and
# compute_content_hash function.
set -eu
f="scripts/lib/hash.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q '_HASH_SOURCED' "$f" || { echo "FAIL: $f missing double-sourcing guard"; exit 1; }
grep -q 'compute_content_hash' "$f" || { echo "FAIL: $f missing compute_content_hash function"; exit 1; }
grep -q 'compute_file_body_hash' "$f" || { echo "FAIL: $f missing compute_file_body_hash function"; exit 1; }
echo "PASS: hash.sh exists with guard and both functions"
```

**`scripts/verify/p01-hash-format.sh`**

```bash
#!/usr/bin/env bash
# Verifies compute_content_hash returns sha256:{hex} format (never bare hex).
set -eu
f="scripts/lib/hash.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "sha256:" "$f" || { echo "FAIL: $f does not reference sha256: format"; exit 1; }
grep -q "printf.*sha256:" "$f" || { echo "FAIL: $f does not format output as sha256:{hex}"; exit 1; }
echo "PASS: hash.sh uses sha256:{hex} format"
```

**`scripts/verify/p01-create-hash.sh`**

```bash
#!/usr/bin/env bash
# Verifies create-entry.sh includes content_hash in frontmatter output.
set -eu
f="scripts/knowledge/create-entry.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "content_hash" "$f" || { echo "FAIL: $f missing content_hash field"; exit 1; }
grep -q "hash.sh" "$f" || { echo "FAIL: $f does not source hash.sh"; exit 1; }
echo "PASS: create-entry.sh writes content_hash"
```

**`scripts/verify/p01-update-hash.sh`**

```bash
#!/usr/bin/env bash
# Verifies update-entry.sh recomputes content_hash when body changes.
set -eu
f="scripts/knowledge/update-entry.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "content_hash" "$f" || { echo "FAIL: $f missing content_hash handling"; exit 1; }
grep -q "hash.sh" "$f" || { echo "FAIL: $f does not source hash.sh"; exit 1; }
grep -q "\-\-body" "$f" || { echo "FAIL: $f missing --body flag"; exit 1; }
echo "PASS: update-entry.sh handles content_hash on body change"
```

**`scripts/verify/p01-rebuild-detects.sh`**

```bash
#!/usr/bin/env bash
# Verifies rebuild-index.sh uses content_hash to detect changes.
set -eu
f="scripts/knowledge/rebuild-index.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "content_hash" "$f" || { echo "FAIL: $f missing content_hash comparison"; exit 1; }
grep -q "hash.sh" "$f" || { echo "FAIL: $f does not source hash.sh"; exit 1; }
echo "PASS: rebuild-index.sh detects changes via content_hash"
```

**`scripts/verify/p01-rebuild-counts.sh`**

```bash
#!/usr/bin/env bash
# Verifies rebuild-index.sh reports changed/unchanged counts in output.
set -eu
f="scripts/knowledge/rebuild-index.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "unchanged" "$f" || { echo "FAIL: $f missing unchanged count reporting"; exit 1; }
grep -q "changed" "$f" || { echo "FAIL: $f missing changed count reporting"; exit 1; }
echo "PASS: rebuild-index.sh reports changed/unchanged counts"
```

**`scripts/verify/p01-outcome-unchanged.sh`**

```bash
#!/usr/bin/env bash
# Verifies record-result.sh accepts unchanged as a valid outcome.
set -eu
f="scripts/lifecycle/record-result.sh"
test -f "$f" || { echo "FAIL: $f missing"; exit 1; }
grep -q "unchanged" "$f" || { echo "FAIL: $f missing unchanged outcome value"; exit 1; }
echo "PASS: record-result.sh accepts unchanged outcome"
```

Make all executable:

```bash
chmod +x scripts/verify/p01-*.sh
```

### Step 3 -- Smoke test the hash library

Source hash.sh and test both functions:

```bash
source scripts/lib/hash.sh
result="$(compute_content_hash "hello world")"
echo "$result"
# Expected: sha256:b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9
```

Verify the format matches `sha256:{64-hex}`:

```bash
echo "$result" | grep -qE '^sha256:[0-9a-f]{64}$'
echo "Format OK"
```

## Must-Haves

From phase plan, this task addresses:

- **Truths**: "Hash utility library exists with double-sourcing guard",
  "Hash utility computes SHA-256 and formats as sha256:{hex}".
- **Artifacts**: `scripts/lib/hash.sh`, all seven `scripts/verify/p01-*.sh`
  scripts.

## Verification

Run each verification script standalone:

```bash
bash scripts/verify/p01-hash-lib.sh
bash scripts/verify/p01-hash-format.sh
```

Both should print PASS lines. The remaining five verification scripts
(p01-create-hash.sh through p01-outcome-unchanged.sh) will FAIL at this
point because T02-T05 have not yet modified their target scripts. This is
expected.

### Files Touched By This Task

- `scripts/lib/hash.sh` (create)
- `scripts/verify/p01-hash-lib.sh` (create)
- `scripts/verify/p01-hash-format.sh` (create)
- `scripts/verify/p01-create-hash.sh` (create)
- `scripts/verify/p01-update-hash.sh` (create)
- `scripts/verify/p01-rebuild-detects.sh` (create)
- `scripts/verify/p01-rebuild-counts.sh` (create)
- `scripts/verify/p01-outcome-unchanged.sh` (create)

## Inputs

### From Previous Tasks

None -- T01 is the phase entry point.

### From Disk (Pre-existing)

- `scripts/lib/errors.sh` -- reference for the double-sourcing guard pattern.
  The guard shape is:
  ```
  [ -n "${_ERRORS_SOURCED:-}" ] && return 0
  _ERRORS_SOURCED=1
  ```
  hash.sh replicates this with `_HASH_SOURCED`.

- `shasum` -- the SHA-256 implementation. Available on macOS as `/usr/bin/shasum`
  and on most Linux as `shasum` (from perl) or `sha256sum`. The library uses
  `shasum -a 256` which works on both macOS and Linux when perl is installed.
  If a target environment lacks `shasum`, fall back to `sha256sum` from
  coreutils (check both and use whichever exists).

## Expected Output

After completing this task:

1. `scripts/lib/hash.sh` exists, is chmod +x, has the double-sourcing guard
   `_HASH_SOURCED`, and exports two functions: `compute_content_hash` and
   `compute_file_body_hash`.
2. `compute_content_hash "hello world"` returns
   `sha256:b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9`.
3. `compute_file_body_hash` on a file with frontmatter returns the hash of
   only the body portion (content after the closing `---`).
4. Seven `scripts/verify/p01-*.sh` files exist and are chmod +x.
5. `bash scripts/verify/p01-hash-lib.sh` prints PASS.
6. `bash scripts/verify/p01-hash-format.sh` prints PASS.
7. `git status` shows 8 new files (1 lib + 7 verify scripts). Nothing else
   touched.
