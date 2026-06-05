---
schema_version: "1.0"
type: task-plan
task: "T01"
phase: "P01"
milestone: "M043"
name: "Config schema (FR-1) + shared deploy_target resolver"
depends_on: []
---

## Prerequisites

- `templates/orchestrator-config-default.yml` exists with a `wiki:` block (lines ~209–229: `landing_cards: []`, `code_prefixes: []`, `spec_paths: []`). Verified present at plan time.
- `tools/verify/` exists.

## Description

Add the `wiki.deploy_target` config switch (FR-1) and a small framework-owned resolver both wiki-init.sh and wiki-deploy.sh will call. The resolver reads the **project's** config (`<root>/.orchestrator/config.yml`), so it must take an explicit project-root argument — this is why we do NOT extend `scripts/state/read-config.sh` (its nested-key handlers hardcode the framework repo as the resolution root, which is wrong when wiki-init operates on a separate consumer PROJECT_DIR).

Default behavior (FR-1): `github-pages` when the key is absent. Edge case (spec "unknown value fails fast"): a **present-but-unrecognized** value exits 2 with a two-value error — it must NOT silently fall through to github-pages.

## Steps

1. **Add the FR-1 block to `templates/orchestrator-config-default.yml`.** Insert the following AFTER the existing `spec_paths: []` line (currently line ~228), still inside the `wiki:` block (2-space indent). Use the Edit tool, anchoring on the `spec_paths: []` line:

   ```yaml
     spec_paths: []                # e.g. [spec/<plan>.md]

     # --- M043 — Wiki deploy target (FR-1) ---
     # deploy_target selects where the emitted CI workflow + `wiki-init.sh
     # --deploy` publish the wiki. Exactly two values (no general multi-cloud
     # abstraction — see spec Non-Goals):
     #   github-pages (default) — emits .github/workflows/pages.yml, publishes
     #     via actions/deploy-pages. NOTE: a *private* Pages site is GitHub
     #     Enterprise-Cloud-only; on Free/Pro/Team the site is PUBLIC, or 422s
     #     on deploy while the build stays green (see references/installation.md).
     #     status/doctor warn on the (private repo + github-pages) tuple.
     #   cloudflare-access — emits .github/workflows/wiki-cloudflare.yml, deploys
     #     via `npx --yes wrangler@4 pages deploy` to Cloudflare Pages fronted by
     #     Cloudflare Access (SSO / one-time-PIN). Plan-independent private wiki;
     #     requires a one-time Cloudflare Zero Trust enablement + provisioning
     #     via scripts/wiki/cloudflare-access-setup.sh.
     deploy_target: github-pages

     # cloudflare: inputs for deploy_target: cloudflare-access. Uncomment + fill
     # when using the Cloudflare target. project_name is the Cloudflare Pages
     # project (the site is <project_name>.pages.dev). The account id is read
     # from the CLOUDFLARE_ACCOUNT_ID repo secret at deploy time, not stored
     # here. allowed_email_domains gates the Access allow policy.
     # CON-7 CAVEAT: allowed_email_domains is a LIST and the M037 yaml-merge
     # primitive has a known list-element preservation gap, so edits to it must
     # be re-applied by re-running cloudflare-access-setup.sh, NOT by editing
     # config and relying on `orchestrator:update` merge — a silently emptied
     # domain list locks every user out of the wiki.
     # cloudflare:
     #   project_name: my-wiki
     #   allowed_email_domains:
     #     - example.com
   ```

2. **Create `scripts/wiki/resolve-deploy-target.sh`** — verbatim:

   ```bash
   #!/usr/bin/env bash
   # scripts/wiki/resolve-deploy-target.sh — resolve wiki.deploy_target for a
   # project. Reads <root>/.orchestrator/config.yml. Returns:
   #   github-pages      when the key/wiki-block/file is absent (FR-1 default)
   #   github-pages      when explicitly set to github-pages
   #   cloudflare-access when explicitly set to cloudflare-access
   #   exit 2 + stderr   when the value is present but not a valid enum member
   #                     (spec Edge Case: unknown value fails fast, never a
   #                     silent fall-through to github-pages)
   #
   # Usage: resolve-deploy-target.sh <project-root>
   # Bash 3.2 / POSIX-sh. No declare -A, no process substitution.
   set -u

   ROOT="${1:-.}"
   CFG="$ROOT/.orchestrator/config.yml"
   DEFAULT="github-pages"

   val=""
   if [ -f "$CFG" ]; then
     # Walk the top-level `wiki:` block for a 2-space-indented deploy_target: key.
     val="$(awk '
       BEGIN { in_wiki = 0 }
       /^wiki:[[:space:]]*$/      { in_wiki = 1; next }
       in_wiki && /^[^[:space:]]/ { exit }
       in_wiki && /^[[:space:]][[:space:]]deploy_target:/ {
         line = $0
         sub(/^[[:space:]]*deploy_target:[[:space:]]*/, "", line)
         sub(/[[:space:]]*#.*$/, "", line)
         gsub(/"/, "", line)
         gsub(/[[:space:]]/, "", line)
         print line
         exit
       }
     ' "$CFG" 2>/dev/null || true)"
   fi

   case "$val" in
     "")
       printf '%s\n' "$DEFAULT"
       ;;
     github-pages|cloudflare-access)
       printf '%s\n' "$val"
       ;;
     *)
       printf 'resolve-deploy-target: unknown wiki.deploy_target value "%s" in %s (valid: github-pages, cloudflare-access)\n' "$val" "$CFG" >&2
       exit 2
       ;;
   esac
   exit 0
   ```

3. **`chmod +x scripts/wiki/resolve-deploy-target.sh`** (single command).

4. **Create `tools/verify/m043-p01-config-and-resolver.sh`** — verbatim:

   ```bash
   #!/usr/bin/env bash
   # m043-p01-config-and-resolver.sh — FR-1 config schema + resolver behavior.
   set -u

   fail=0
   check() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }

   CFG="templates/orchestrator-config-default.yml"
   grep -q "deploy_target: github-pages" "$CFG"; check "config declares deploy_target: github-pages default" $?
   grep -q "allowed_email_domains" "$CFG";        check "config documents allowed_email_domains" $?
   grep -q "cloudflare-access" "$CFG";             check "config names the cloudflare-access value" $?

   R="scripts/wiki/resolve-deploy-target.sh"
   test -x "$R"; check "resolver is executable" $?

   TMP="$(mktemp -d)"

   # absent -> github-pages
   mkdir -p "$TMP/absent/.orchestrator"
   printf 'wiki:\n  landing_cards: []\n' > "$TMP/absent/.orchestrator/config.yml"
   out="$(bash "$R" "$TMP/absent" 2>/dev/null)"
   [ "$out" = "github-pages" ]; check "absent deploy_target -> github-pages (got '$out')" $?

   # explicit github-pages
   mkdir -p "$TMP/gh/.orchestrator"
   printf 'wiki:\n  deploy_target: github-pages\n' > "$TMP/gh/.orchestrator/config.yml"
   out="$(bash "$R" "$TMP/gh" 2>/dev/null)"
   [ "$out" = "github-pages" ]; check "explicit github-pages -> github-pages (got '$out')" $?

   # cloudflare-access
   mkdir -p "$TMP/cf/.orchestrator"
   printf 'wiki:\n  deploy_target: cloudflare-access\n' > "$TMP/cf/.orchestrator/config.yml"
   out="$(bash "$R" "$TMP/cf" 2>/dev/null)"
   [ "$out" = "cloudflare-access" ]; check "cloudflare-access -> cloudflare-access (got '$out')" $?

   # unknown value -> exit 2
   mkdir -p "$TMP/bad/.orchestrator"
   printf 'wiki:\n  deploy_target: netlify\n' > "$TMP/bad/.orchestrator/config.yml"
   bash "$R" "$TMP/bad" >/dev/null 2>&1
   rc=$?
   [ "$rc" -eq 2 ]; check "unknown value exits 2 (got rc=$rc)" $?

   rm -rf "$TMP"

   if [ "$fail" -eq 0 ]; then echo "SUMMARY: m043-p01-config-and-resolver.sh pass=ALL fail=0"; exit 0; fi
   echo "SUMMARY: m043-p01-config-and-resolver.sh pass=SOME fail=1"; exit 1
   ```

5. **`chmod +x tools/verify/m043-p01-config-and-resolver.sh`** (single command).

6. Run the verification block below; confirm all exit 0.

## Must-Haves

- FR-1 config schema present (deploy_target default + commented cloudflare sub-block + CON-7 caveat).
- resolve-deploy-target.sh returns default on absent, echoes valid values, exits 2 on unknown.

## Verification

- `bash tools/verify/m043-p01-config-and-resolver.sh`
- `test -x scripts/wiki/resolve-deploy-target.sh`
- `grep -q "deploy_target: github-pages" templates/orchestrator-config-default.yml`

## Inputs

### From Previous Tasks

None.

### From Disk (Pre-existing)

- `templates/orchestrator-config-default.yml` — the `wiki:` block (lines ~209–229); insert the FR-1 block after `spec_paths: []`. Preserve the existing keys verbatim (Principle: additive only).

## Constraints

- **Bash 3.2 / POSIX-sh** (CON-5): no `declare -A`, no process substitution, no `mapfile`. The `$(mktemp -d)` + `awk` + `case` forms above are 3.2-safe.
- **Additive config edit only** — do not reorder or alter existing `wiki:` keys (`landing_cards`, `code_prefixes`, `spec_paths`); CON-4 byte-stability of the github-pages path depends on no behavioral change to existing config consumers.
- **Resolver default is github-pages on absence; exit 2 on unknown** — these are different paths; do not collapse them (the edge case is explicit in the spec).
- **Project-owned verifier under `tools/verify/`**, milestone-slug-prefixed. Do not emit to `scripts/verify/`.
- Bash shape-guard (AP-009): run shell commands singly; do not chain `&&`/`;` > 2. (Verifier-internal complexity is fine — it runs as a script file.)

## Expected Output

The config gains the FR-1 block; `resolve-deploy-target.sh` + its verifier are executable. `bash tools/verify/m043-p01-config-and-resolver.sh` ends with `SUMMARY: m043-p01-config-and-resolver.sh pass=ALL fail=0` and exit 0.
