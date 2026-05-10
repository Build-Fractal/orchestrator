---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P02"
milestone: "M012"
name: "P02 verification suite + D011-EVALUATION.md + phase-suite orchestrator"
depends_on: ["T04"]
---

## Prerequisites

- T01–T04 complete:
  - `wiki/mkdocs.yml` has link-rewriting config.
  - `wiki/docs/knowledge/**` stub tree populated; nav updated with `Knowledge Entries:` subtree.
  - `scripts/diagnostics/wiki-link-check.sh` exists, executable, contract verified.
  - `wiki/README.md` has "Link resolution", "Running the link checker", and "Pre-deploy integration (P04)" sections.
  - `bash scripts/verify/m012-p01-phase-suite.sh` still exits 0.
- No P02 verify scripts exist yet. T05 creates all of them plus the phase-suite orchestrator plus the D011 evaluation record.

## Description

Ship the nine M012/P02 verification gates + phase-suite orchestrator, following the exact pattern P01/T05 established. Each gate is an AD-19 single-invocation Bash 3.2 script callable as a Truth `Check:` command. Plus: ship the `D011-EVALUATION.md` artifact — a structured record of the mechanical 1-of-3 outcome that the roadmap's cross-cutting concern commits to producing at P02 close.

### Nine gates (one per Truth in P02-PLAN.md)

1. `m012-p02-link-rewrite-config.sh` — asserts `wiki/mkdocs.yml` has `rewrite_relative_urls: true` on include-markdown and `toc: { permalink: true }` under `markdown_extensions:`.
2. `m012-p02-mem-stubs.sh` — asserts `wiki/docs/knowledge/<category>/<MEM###>.md` exists for every `knowledge/<category>/MEM*.md`; each stub ≤ 25 lines; each carries one include-markdown directive; four section-index files present.
3. `m012-p02-mem-anchors.sh` — when mkdocs is available, builds the site to a throwaway directory and checks that the rendered KNOWLEDGE page has at least one heading anchor matching `id="mem-…"` form (proves the anchor-resolution chain is functional). When mkdocs is absent, emits `SKIP:` and exits 0.
4. `m012-p02-link-check-contract.sh` — asserts `scripts/diagnostics/wiki-link-check.sh` exists, is executable, emits structured `BROKEN:` / `OUT-OF-SCOPE:` lines on a synthetic fixture, produces `PASS:` or `FAIL:` summary, and exits 0/1 correctly. Uses a self-contained HTML fixture under `/tmp/` — does not require mkdocs.
5. `m012-p02-link-check-help.sh` — asserts `bash scripts/diagnostics/wiki-link-check.sh --help` exits 0 and output mentions `--site`, `--root`, `--strict`, "In-scope", "Out-of-scope", "Broken".
6. `m012-p02-readme-policy.sh` — asserts `wiki/README.md` has the three required headings, mentions `wiki-link-check.sh`, mentions `mkdocs build --strict`, has ≥ 80 lines.
7. `m012-p02-link-check-smoke.sh` — if mkdocs is available, runs `wiki-serve.sh --probe` to produce a real build, then runs `wiki-link-check.sh --site <probe-site>`, asserts exit 0. If mkdocs is absent, emits `SKIP: mkdocs not installed` and exits 0 (Tier 1 skip-as-PASS; Tier 4 UAT covers the real thing).
8. `m012-p02-bash32-compat.sh` — scans every `.sh` file created or touched by P02 (`scripts/diagnostics/wiki-link-check.sh`, every `scripts/verify/m012-p02-*.sh`, and the T01/T02 edits to `scripts/wiki/wiki-*.sh`) for Bash 4-only constructs.
9. `m012-p02-d011-evaluation.sh` — asserts [`.orchestrator/milestones/M012/phases/P02/D011-EVALUATION.md`](../../../../milestones/M012/phases/P02/D011-EVALUATION.md) exists with the required frontmatter + body shape + "[M020](../../../../milestones/M020/index.md) promoted" conclusion.

Plus the orchestrator:

10. `m012-p02-phase-suite.sh` — runs the nine gates, emits one `GATE: <name> PASS|FAIL` per gate, summary to stderr, exits 0 iff all nine pass.

## Steps

1. **Create [`.orchestrator/milestones/M012/phases/P02/D011-EVALUATION.md`](../../../../milestones/M012/phases/P02/D011-EVALUATION.md)** — the structured record. Body shape:

   ```markdown
   ---
   schema_version: "1.0"
   type: d011-evaluation
   milestone: "M012"
   phase: "P02"
   decision: "D011"
   ---

   # D011 Mechanical Evaluation — M012/P02 close

   Per [`.orchestrator/DECISIONS.md`](../../../../decisions.md) D011 and [`.orchestrator/milestones/M012/M012-CONTEXT.md`](../../../../milestones/M012/M012-CONTEXT.md)
   AD-1, this evaluation counts how many of D011's three criteria M012 ships.
   The count is mechanical: it does not reassess the decision, it records the
   outcome of the decision-in-effect.

   ## Criteria

   | # | Criterion | Shipped in M012? | Evidence |
   |---|-----------|------------------|----------|
   | a | Cross-refs to `knowledge/**/MEM*.md` | **Yes** | M012/P02/T01 (scanner extension) + M012/P02/T02 (stub + nav generation) + M012/P02/T03 (link checker validates resolution). Rendered wiki resolves `knowledge/<cat>/MEM###.md` file-path references to rendered stub routes; see `wiki/README.md` "Link resolution" section. |
   | b | Reviewed/unreviewed state per page | **No** | Explicitly deferred to M020 per AD-1 (speculative complexity for a dogfood wiki — Constitution XIV). No review-state UI, metadata, or workflow ships in M012. |
   | c | Dispatch-callable query surface | **No** | Explicitly deferred to M020 per AD-1. The wiki is a read-only rendering surface; no programmatic query API, no MCP/CLI query tool, no index-as-service. |

   ## Outcome

   **1 of 3 criteria shipped → M020 is PROMOTED** per D011's trigger rule
   (≤ 1 of 3 → promote as a committed milestone).

   ## Downstream implication

   Post-M012 the roadmap is updated to position M020 between [M014](../../../../milestones/M014/index.md) and [M019](../../../../milestones/M019/index.md)
   Tier 2/3, per D011's framing (see [`.orchestrator/DECISIONS.md`](../../../../decisions.md) D011 for the
   positioning rationale). That roadmap update is NOT part of M012/P02 —
   M012's phase closes with this record emitted; the roadmap adjustment is a
   consolidation-time action (`speckit.orchestrator.consolidate` on M012
   close, or whenever the roadmap is next regenerated).

   ## References

   - [`.orchestrator/DECISIONS.md`](../../../../decisions.md) — D011 (trigger rule + criteria definitions).
   - [`.orchestrator/milestones/M012/M012-CONTEXT.md`](../../../../milestones/M012/M012-CONTEXT.md) — AD-1 (criteria selection rationale).
   - [`.orchestrator/milestones/M012/M012-ROADMAP.md`](../../../../milestones/M012/M012-ROADMAP.md) — cross-cutting-concern bullet committing this evaluation to P02.
   - `.orchestrator/milestones/M012/phases/P02/P02-PLAN.md` — D011-EVALUATION artifact listed in Artifacts and Key Links.
   ```

   The file must contain the literal string "M020 promoted" (T05's gate asserts on it). Line count ≥ 30.

2. **Create `scripts/verify/m012-p02-link-rewrite-config.sh`**:

   ```bash
   #!/usr/bin/env bash
   # scripts/verify/m012-p02-link-rewrite-config.sh — M012/P02 gate 1.
   # Asserts wiki/mkdocs.yml has rewrite_relative_urls and toc permalink.
   set -u
   ROOT="${1:-$(pwd)}"
   ymlfile="$ROOT/wiki/mkdocs.yml"
   [ -f "$ymlfile" ] || { printf 'FAIL: mkdocs.yml missing: %s\n' "$ymlfile"; exit 1; }
   grep -qF 'rewrite_relative_urls: true' "$ymlfile" \
     || { printf 'FAIL: missing "rewrite_relative_urls: true" in %s\n' "$ymlfile"; exit 1; }
   grep -qE '^[[:space:]]*-[[:space:]]*toc' "$ymlfile" \
     || { printf 'FAIL: missing "- toc" in markdown_extensions of %s\n' "$ymlfile"; exit 1; }
   grep -qE 'permalink:[[:space:]]*true' "$ymlfile" \
     || { printf 'FAIL: missing "permalink: true" under toc in %s\n' "$ymlfile"; exit 1; }
   printf 'PASS: link-rewrite config present\n'
   exit 0
   ```

3. **Create `scripts/verify/m012-p02-mem-stubs.sh`**:

   ```bash
   #!/usr/bin/env bash
   # M012/P02 gate 2 — knowledge stubs + section indexes.
   set -u
   ROOT="${1:-$(pwd)}"
   src_count=$(find "$ROOT/knowledge" -type f -name 'MEM*.md' 2>/dev/null | wc -l | tr -d ' ')
   stub_count=$(find "$ROOT/wiki/docs/knowledge" -type f -name 'MEM*.md' \
                  -not -name 'index.md' 2>/dev/null | wc -l | tr -d ' ')
   if [ "$src_count" != "$stub_count" ]; then
     printf 'FAIL: MEM stub count %s != source count %s\n' "$stub_count" "$src_count"
     exit 1
   fi
   # Each stub must be ≤ 25 lines and carry exactly one include-markdown directive.
   find "$ROOT/wiki/docs/knowledge" -type f -name 'MEM*.md' \
     -not -name 'index.md' | while IFS= read -r stub; do
       lines=$(wc -l < "$stub" | tr -d ' ')
       if [ "$lines" -gt 25 ]; then
         printf 'FAIL: %s has %s lines (> 25)\n' "$stub" "$lines"
         exit 1
       fi
       incs=$(grep -c 'include-markdown' "$stub")
       if [ "$incs" != "1" ]; then
         printf 'FAIL: %s has %s include-markdown directives (expected 1)\n' "$stub" "$incs"
         exit 1
       fi
     done
   # Four section indexes.
   for p in \
     "$ROOT/wiki/docs/knowledge/index.md" \
     "$ROOT/wiki/docs/knowledge/patterns/index.md" \
     "$ROOT/wiki/docs/knowledge/conventions/index.md" \
     "$ROOT/wiki/docs/knowledge/lessons/index.md"; do
     [ -f "$p" ] || { printf 'FAIL: missing section index %s\n' "$p"; exit 1; }
     grep -qF 'Auto-generated section index' "$p" \
       || { printf 'FAIL: %s missing "Auto-generated section index" probe\n' "$p"; exit 1; }
   done
   printf 'PASS: %s MEM stubs + 4 section indexes present\n' "$stub_count"
   exit 0
   ```

   Note the `while | exit 1` pattern requires a workaround on Bash 3.2 (exit in subshell doesn't propagate). Use a findings-file approach instead:

   ```bash
   fails="/tmp/m012-p02-mem-stubs.$$"
   : > "$fails"
   find "$ROOT/wiki/docs/knowledge" -type f -name 'MEM*.md' \
     -not -name 'index.md' > "/tmp/m012-p02-mem-stubs.list.$$"
   while IFS= read -r stub; do
     [ -n "$stub" ] || continue
     lines=$(wc -l < "$stub" | tr -d ' ')
     [ "$lines" -le 25 ] || echo "FAIL: $stub has $lines lines" >> "$fails"
     incs=$(grep -c 'include-markdown' "$stub")
     [ "$incs" = "1" ] || echo "FAIL: $stub has $incs include dirs" >> "$fails"
   done < "/tmp/m012-p02-mem-stubs.list.$$"
   rm -f "/tmp/m012-p02-mem-stubs.list.$$"
   if [ -s "$fails" ]; then
     cat "$fails"
     rm -f "$fails"
     exit 1
   fi
   rm -f "$fails"
   ```

4. **Create `scripts/verify/m012-p02-mem-anchors.sh`**:

   ```bash
   #!/usr/bin/env bash
   # M012/P02 gate 3 — rendered KNOWLEDGE page has MEM heading anchors.
   set -u
   ROOT="${1:-$(pwd)}"
   if ! command -v mkdocs >/dev/null 2>&1; then
     printf 'SKIP: mkdocs not installed — anchor check deferred to Tier 4 UAT\n'
     exit 0
   fi
   probe_dir="/tmp/m012-p02-anchors.$$"
   mkdir -p "$probe_dir"
   trap 'rm -rf "$probe_dir"' EXIT
   (cd "$ROOT/wiki" && mkdocs build --site-dir "$probe_dir" --quiet) \
     || { printf 'FAIL: mkdocs build failed\n'; exit 1; }
   # Find the rendered KNOWLEDGE.md page.
   knowledge_html=$(find "$probe_dir" -type f -name 'index.html' -path '*knowledge*' \
                     | head -n 1)
   [ -n "$knowledge_html" ] || { printf 'FAIL: rendered KNOWLEDGE page not found in %s\n' "$probe_dir"; exit 1; }
   # MEM anchors may be either from consolidated KNOWLEDGE.md headings OR
   # from per-entry stubs (T02). Either form is acceptable for the gate.
   if grep -qiE 'id="mem[-_]?[0-9]+"' "$knowledge_html"; then
     printf 'PASS: KNOWLEDGE renders with at least one MEM heading anchor\n'
     exit 0
   fi
   # If the consolidated page lacks MEM anchors, check that at least one
   # per-entry MEM stub renders with a heading anchor.
   mem_stub_html=$(find "$probe_dir" -type f -name 'index.html' \
                     -path '*knowledge/patterns/MEM*' | head -n 1)
   if [ -n "$mem_stub_html" ] && grep -qiE 'id="mem[-_]?[0-9]+"' "$mem_stub_html"; then
     printf 'PASS: MEM stub renders with heading anchor (per-entry path)\n'
     exit 0
   fi
   printf 'FAIL: no MEM heading anchor found in rendered output\n'
   exit 1
   ```

5. **Create `scripts/verify/m012-p02-link-check-contract.sh`**:

   ```bash
   #!/usr/bin/env bash
   # M012/P02 gate 4 — link-check script contract via synthetic fixture.
   set -u
   ROOT="${1:-$(pwd)}"
   script="$ROOT/scripts/diagnostics/wiki-link-check.sh"
   [ -x "$script" ] || { printf 'FAIL: %s not executable\n' "$script"; exit 1; }
   # Build a synthetic fixture: two HTML pages with a mix of in-scope / broken / external links.
   fx="/tmp/m012-p02-linkfx.$$"
   mkdir -p "$fx/sub"
   trap 'rm -rf "$fx"' EXIT
   cat > "$fx/index.html" <<'EOF'
   <html><body>
   <a href="sub/target.html">ok internal</a>
   <a href="sub/missing.html">broken internal</a>
   <a href="https://example.com/">external</a>
   <a href="#nope">broken anchor</a>
   </body></html>
   EOF
   cat > "$fx/sub/target.html" <<'EOF'
   <html><body><h1 id="hdr">hi</h1></body></html>
   EOF
   out=$(bash "$script" --site "$fx" 2>&1)
   rc=$?
   echo "$out" | grep -q 'BROKEN:.*sub/missing.html' \
     || { printf 'FAIL: missing BROKEN line for sub/missing.html\n%s\n' "$out"; exit 1; }
   echo "$out" | grep -q 'OUT-OF-SCOPE:.*example.com' \
     || { printf 'FAIL: missing OUT-OF-SCOPE line for example.com\n%s\n' "$out"; exit 1; }
   echo "$out" | grep -q 'BROKEN:.*#nope' \
     || { printf 'FAIL: missing BROKEN line for #nope anchor\n%s\n' "$out"; exit 1; }
   echo "$out" | grep -qE '^FAIL: [0-9]+ broken' \
     || { printf 'FAIL: missing FAIL summary\n%s\n' "$out"; exit 1; }
   [ "$rc" = "1" ] || { printf 'FAIL: expected exit 1, got %s\n' "$rc"; exit 1; }
   printf 'PASS: link-check contract verified against synthetic fixture\n'
   exit 0
   ```

6. **Create `scripts/verify/m012-p02-link-check-help.sh`**:

   ```bash
   #!/usr/bin/env bash
   # M012/P02 gate 5 — --help usage block.
   set -u
   ROOT="${1:-$(pwd)}"
   script="$ROOT/scripts/diagnostics/wiki-link-check.sh"
   out=$(bash "$script" --help 2>&1)
   rc=$?
   [ "$rc" = "0" ] || { printf 'FAIL: --help exit %s\n' "$rc"; exit 1; }
   for kw in "--site" "--root" "--strict" "In-scope" "Out-of-scope" "Broken"; do
     echo "$out" | grep -qF "$kw" \
       || { printf 'FAIL: --help missing keyword: %s\n' "$kw"; exit 1; }
   done
   printf 'PASS: --help enumerates all flags and classification rules\n'
   exit 0
   ```

7. **Create `scripts/verify/m012-p02-readme-policy.sh`**:

   ```bash
   #!/usr/bin/env bash
   # M012/P02 gate 6 — wiki/README.md link-resolution policy section.
   set -u
   ROOT="${1:-$(pwd)}"
   f="$ROOT/wiki/README.md"
   [ -f "$f" ] || { printf 'FAIL: %s missing\n' "$f"; exit 1; }
   for hdr in \
     '^## Link resolution$' \
     '^## Running the link checker$' \
     '^## Pre-deploy integration (P04)$'; do
     count=$(grep -c -E "$hdr" "$f")
     [ "$count" = "1" ] || { printf 'FAIL: %s — expected 1 match for %s, got %s\n' "$f" "$hdr" "$count"; exit 1; }
   done
   grep -qF 'wiki-link-check.sh' "$f" \
     || { printf 'FAIL: README missing wiki-link-check.sh reference\n'; exit 1; }
   grep -qF 'mkdocs build --strict' "$f" \
     || { printf 'FAIL: README missing "mkdocs build --strict" reference\n'; exit 1; }
   lines=$(wc -l < "$f" | tr -d ' ')
   [ "$lines" -ge 80 ] || { printf 'FAIL: README %s lines (< 80)\n' "$lines"; exit 1; }
   printf 'PASS: README policy section present (%s lines)\n' "$lines"
   exit 0
   ```

8. **Create `scripts/verify/m012-p02-link-check-smoke.sh`**:

   ```bash
   #!/usr/bin/env bash
   # M012/P02 gate 7 — end-to-end smoke against a real mkdocs build.
   set -u
   ROOT="${1:-$(pwd)}"
   if ! command -v mkdocs >/dev/null 2>&1; then
     printf 'SKIP: mkdocs not installed — link-check smoke deferred to Tier 4 UAT\n'
     exit 0
   fi
   probe="/tmp/m012-p02-linksmoke.$$"
   mkdir -p "$probe"
   trap 'rm -rf "$probe"' EXIT
   (cd "$ROOT/wiki" && mkdocs build --site-dir "$probe" --quiet) \
     || { printf 'FAIL: mkdocs build failed\n'; exit 1; }
   out=$(bash "$ROOT/scripts/diagnostics/wiki-link-check.sh" --site "$probe" 2>&1)
   rc=$?
   if [ "$rc" != "0" ]; then
     printf 'FAIL: link-check against real build exit %s\n%s\n' "$rc" "$out"
     exit 1
   fi
   echo "$out" | grep -qE '^PASS: 0 broken' \
     || { printf 'FAIL: link-check stdout missing PASS summary\n%s\n' "$out"; exit 1; }
   printf 'PASS: real-build link-check clean\n'
   exit 0
   ```

9. **Create `scripts/verify/m012-p02-bash32-compat.sh`**:

   ```bash
   #!/usr/bin/env bash
   # M012/P02 gate 8 — Bash 3.2 compat for every P02-touched .sh.
   set -u
   ROOT="${1:-$(pwd)}"
   targets="/tmp/m012-p02-bash32.$$"
   : > "$targets"
   echo "$ROOT/scripts/diagnostics/wiki-link-check.sh" >> "$targets"
   find "$ROOT/scripts/verify" -type f -name 'm012-p02-*.sh' >> "$targets"
   echo "$ROOT/scripts/wiki/wiki-scan-sources.sh" >> "$targets"
   echo "$ROOT/scripts/wiki/wiki-generate-stubs.sh" >> "$targets"
   echo "$ROOT/scripts/wiki/wiki-generate-nav.sh" >> "$targets"
   # Patterns to forbid (parallel arrays — PAT_REGEX_* / PAT_LABEL_*, P01 pattern).
   PAT_REGEX_0='declare -A'
   PAT_LABEL_0='declare -A (Bash 4 associative array)'
   PAT_REGEX_1='mapfile'
   PAT_LABEL_1='mapfile (Bash 4 builtin)'
   PAT_REGEX_2='readarray'
   PAT_LABEL_2='readarray (Bash 4 builtin)'
   PAT_REGEX_3='\$\{[A-Za-z_][A-Za-z0-9_]*\^\^\}'
   PAT_LABEL_3='${var^^} (Bash 4 uppercase expansion)'
   PAT_REGEX_4='\$\{[A-Za-z_][A-Za-z0-9_]*,,\}'
   PAT_LABEL_4='${var,,} (Bash 4 lowercase expansion)'
   PAT_REGEX_5='<\('
   PAT_LABEL_5='<(...) (process substitution)'
   PAT_REGEX_6='>\('
   PAT_LABEL_6='>(...) (process substitution)'
   PAT_REGEX_7='&>'
   PAT_LABEL_7='&> (Bash 4 merge redirect)'
   fails="/tmp/m012-p02-bash32-fails.$$"
   : > "$fails"
   while IFS= read -r f; do
     [ -n "$f" ] || continue
     [ -f "$f" ] || continue
     i=0
     while [ "$i" -le 7 ]; do
       eval "rx=\"\$PAT_REGEX_$i\""
       eval "lbl=\"\$PAT_LABEL_$i\""
       # Match non-comment lines only (strip leading #-prefixed lines).
       # Also skip assignment-line self-scan carve-out (lines beginning with PAT_REGEX_ or PAT_LABEL_).
       grep -nE "$rx" "$f" 2>/dev/null \
         | grep -v '^[0-9]*:[[:space:]]*#' \
         | grep -v 'PAT_REGEX_' \
         | grep -v 'PAT_LABEL_' \
         | while IFS= read -r hit; do
             [ -n "$hit" ] || continue
             printf 'FAIL: %s — %s: %s\n' "$f" "$lbl" "$hit" >> "$fails"
           done
       i=$((i + 1))
     done
   done < "$targets"
   rm -f "$targets"
   if [ -s "$fails" ]; then
     cat "$fails"
     rm -f "$fails"
     exit 1
   fi
   rm -f "$fails"
   printf 'PASS: all P02 .sh files are Bash 3.2 compatible\n'
   exit 0
   ```

10. **Create `scripts/verify/m012-p02-d011-evaluation.sh`**:

    ```bash
    #!/usr/bin/env bash
    # M012/P02 gate 9 — D011-EVALUATION.md record.
    set -u
    ROOT="${1:-$(pwd)}"
    f="$ROOT/.orchestrator/milestones/M012/phases/P02/D011-EVALUATION.md"
    [ -f "$f" ] || { printf 'FAIL: %s missing\n' "$f"; exit 1; }
    lines=$(wc -l < "$f" | tr -d ' ')
    [ "$lines" -ge 30 ] || { printf 'FAIL: D011-EVALUATION.md %s lines (< 30)\n' "$lines"; exit 1; }
    # Frontmatter sanity.
    head -n 10 "$f" | grep -qE '^decision:[[:space:]]*"?D011"?' \
      || { printf 'FAIL: frontmatter missing decision: D011\n'; exit 1; }
    head -n 10 "$f" | grep -qE '^milestone:[[:space:]]*"?M012"?' \
      || { printf 'FAIL: frontmatter missing milestone: M012\n'; exit 1; }
    grep -qF 'M020 promoted' "$f" \
      || { printf 'FAIL: missing "M020 promoted" conclusion\n'; exit 1; }
    # Three criteria rows.
    grep -qE 'Cross-refs' "$f" || { printf 'FAIL: missing criterion (a) Cross-refs row\n'; exit 1; }
    grep -qE 'Reviewed' "$f"   || { printf 'FAIL: missing criterion (b) Reviewed row\n'; exit 1; }
    grep -qE 'query surface' "$f" || { printf 'FAIL: missing criterion (c) query surface row\n'; exit 1; }
    # Reference block cites DECISIONS.md and M012-CONTEXT.md.
    grep -qF 'DECISIONS.md' "$f" || { printf 'FAIL: missing DECISIONS.md reference\n'; exit 1; }
    grep -qF 'M012-CONTEXT.md' "$f" || { printf 'FAIL: missing M012-CONTEXT.md reference\n'; exit 1; }
    printf 'PASS: D011-EVALUATION.md structured correctly (%s lines)\n' "$lines"
    exit 0
    ```

11. **Create `scripts/verify/m012-p02-phase-suite.sh`** — the orchestrator (same pattern as P01/T05):

    ```bash
    #!/usr/bin/env bash
    # scripts/verify/m012-p02-phase-suite.sh — runs all nine M012/P02 gates.
    set -u
    ROOT="${1:-$(pwd)}"
    gates=(
      "m012-p02-link-rewrite-config.sh"
      "m012-p02-mem-stubs.sh"
      "m012-p02-mem-anchors.sh"
      "m012-p02-link-check-contract.sh"
      "m012-p02-link-check-help.sh"
      "m012-p02-readme-policy.sh"
      "m012-p02-link-check-smoke.sh"
      "m012-p02-bash32-compat.sh"
      "m012-p02-d011-evaluation.sh"
    )
    passed=0
    total=${#gates[@]}
    for g in "${gates[@]}"; do
      if bash "$ROOT/scripts/verify/$g" "$ROOT"; then
        printf 'GATE: %s PASS\n' "$g"
        passed=$((passed + 1))
      else
        printf 'GATE: %s FAIL\n' "$g"
      fi
    done
    printf 'SUMMARY: %d/%d gates passed\n' "$passed" "$total" >&2
    [ "$passed" -eq "$total" ]
    ```

12. **Make every verify script executable**:

    ```bash
    chmod 755 scripts/verify/m012-p02-*.sh
    ```

13. **Smoke-run the phase-suite**:

    ```bash
    bash scripts/verify/m012-p02-phase-suite.sh
    ```

    Expect `9/9 gates passed`. If any gate fails, diagnose via the per-gate FAIL line, fix the underlying T01–T04 output (not the gate — the gate is the contract), and re-run.

    On a host WITHOUT mkdocs installed, gates 3 (`mem-anchors`) and 7 (`link-check-smoke`) will print `SKIP:` and exit 0 — the phase-suite still reports 9/9 PASS because SKIP maps to PASS at the gate boundary (Tier 1 acceptable; Tier 4 UAT is the path that actually exercises mkdocs).

14. **Confirm the must-haves harness agrees**:

    ```bash
    bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P02
    ```

    Should report all Truth `Check:` commands PASS, all Artifacts (min-lines + contains) PASS, all Key Links PASS. Any FAIL here indicates a mismatch between the P02-PLAN.md assertions and the on-disk state — fix the plan OR fix the on-disk state (prefer the latter; the plan's assertions are the contract).

## Must-Haves

- Nine `scripts/verify/m012-p02-*.sh` files exist, all executable, all Bash 3.2 compliant.
- `scripts/verify/m012-p02-phase-suite.sh` exists, is executable, runs all nine gates.
- `bash scripts/verify/m012-p02-phase-suite.sh` exits 0 against clean T01–T04 output (gates 3 and 7 may SKIP when mkdocs is absent; SKIP maps to PASS).
- [`.orchestrator/milestones/M012/phases/P02/D011-EVALUATION.md`](../../../../milestones/M012/phases/P02/D011-EVALUATION.md) exists, ≥ 30 lines, contains "M020 promoted", frontmatter has `decision: D011` and `milestone: M012`, body enumerates all three criteria and cites DECISIONS.md + M012-CONTEXT.md.
- `bash scripts/verify/m012-p01-phase-suite.sh` still exits 0 (P02 must not regress P01).
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P02` — all assertions PASS.
- Each gate emits one `PASS:` / `FAIL:` / `SKIP:` line to stdout.
- Each gate is individually invokable without the phase-suite harness (accepts `$1` as `ROOT` override; defaults to `$(pwd)`).

## Verification

- `bash scripts/verify/m012-p02-phase-suite.sh` — the suite's own exit code is the phase's exit code.
- `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P02` — confirms artifact paths + patterns (every verify script + the D011 artifact listed in Artifacts section).
- `bash scripts/verify/m012-p01-phase-suite.sh` — still 9/9 green.
- Self-test: run `m012-p02-phase-suite.sh` twice in a row; exit code identical (no hidden state).
- Self-test: temporarily rename `wiki/mkdocs.yml`; run suite; expect `link-rewrite-config` (and likely others) to FAIL with actionable messages. Restore.
- Self-test: temporarily remove `M020 promoted` from D011-EVALUATION.md; run suite; expect `d011-evaluation` to FAIL. Restore.

## Inputs

### From Previous Tasks

- **T01** — `wiki/mkdocs.yml` settings and extended scanner. Contract used by gate 1 (`link-rewrite-config`) and indirectly by every other gate that depends on the scanner's `knowledge:<category>` output.
- **T02** — `wiki/docs/knowledge/` stub tree + `Knowledge Entries:` nav subtree. Contract used by gate 2 (`mem-stubs`).
- **T03** — `scripts/diagnostics/wiki-link-check.sh`:
  - Key API: `--site <dir>` (default `wiki/site`), `--root <dir>`, `--strict`, `--help`.
  - Output: `BROKEN:` / `OUT-OF-SCOPE:` lines; last stdout line `PASS:` or `FAIL:`.
  - Exit: 0 / 1 / 2.
  Contract used by gates 4, 5, 7.
- **T04** — `wiki/README.md` with three new headings + required mentions. Contract used by gate 6.

### From Disk (Pre-existing)

- `scripts/verify/check-must-haves.sh` — the orchestrator's canonical verification harness; consumes the phase plan's Truths + Artifacts + Key Links and runs them. T05 must produce a phase plan + on-disk state that satisfies this harness.
- [`.orchestrator/DECISIONS.md`](../../../../decisions.md) — D011 content (cited by the D011-EVALUATION.md record).
- [`.orchestrator/milestones/M012/M012-CONTEXT.md`](../../../../milestones/M012/M012-CONTEXT.md) — AD-1 (cited by the D011-EVALUATION.md record).
- [`.orchestrator/milestones/M012/M012-ROADMAP.md`](../../../../milestones/M012/M012-ROADMAP.md) — cross-cutting-concern bullet committing the D011 evaluation to P02 close.
- P01 verify scripts (`scripts/verify/m012-p01-*.sh`) — the shape P02 gates mirror; gate 8's `bash32-compat.sh` directly reuses P01's parallel-indexed-array pattern.

## Constraints

- **Bash 3.2** — every verify script (same discipline as P01). MEM001.
- **MEM004 carve-out applies** — gate internals may use pipes, `grep -oE`, `sed`, `awk`, `find | sort`, PID-suffixed temp files. The AD-19 shape constraint applies to the Truth `Check:` commands in P02-PLAN.md (which are single `bash scripts/verify/m012-p02-*.sh` invocations).
- **SKIP-as-PASS** — gates that depend on mkdocs (3, 7) must SKIP cleanly when mkdocs is absent, emitting an explicit `SKIP:` line and exiting 0. Silent pass is NOT acceptable; readers need to see that a check was skipped.
- **Read-only against repo state** — every gate may write to `/tmp/` only. `trap` cleans temp files on exit.
- **Deterministic** — identical T01–T04 output → identical gate outputs across runs.
- **Root-override pattern** — each gate accepts `$1` as a project-root override, defaulting to `$(pwd)`. This supports the phase-suite orchestrator passing `$ROOT` and supports fixture-based testing without requiring invocation from the repo root.
- **No compound bash in Truth `Check:` commands** (AD-19) — every Check in P02-PLAN.md is a single-script-file invocation. Internals of the scripts may use whatever Bash 3.2 features are needed.
- **Surgical precision (Constitution XV)** — T05 creates exactly ten files under `scripts/verify/` (nine gates + one suite) plus one under `.orchestrator/milestones/M012/phases/P02/` (D011-EVALUATION.md). No files outside those two directories are touched.

## Expected Output

After T05 completes:

1. Nine gate scripts + one phase-suite orchestrator under `scripts/verify/` with `m012-p02-` prefix, all executable, all Bash 3.2 compliant.
2. [`.orchestrator/milestones/M012/phases/P02/D011-EVALUATION.md`](../../../../milestones/M012/phases/P02/D011-EVALUATION.md) exists, structured as documented, ≥ 30 lines.
3. `bash scripts/verify/m012-p02-phase-suite.sh` exits 0 (9/9 green; gates 3 and 7 may SKIP on hosts without mkdocs).
4. `bash scripts/verify/check-must-haves.sh .orchestrator/milestones/M012/phases/P02` — all Truths, Artifacts, Key Links PASS.
5. `bash scripts/verify/m012-p01-phase-suite.sh` — still 9/9 green (P02 did not regress P01).
6. Derived state via `bash scripts/state/derive-phase.sh .orchestrator/milestones/M012` — advances from `executing` to the next state according to state-machine rules once P02-SUMMARY.md lands (produced by the verify-and-summarize step at phase close, not by this task).
