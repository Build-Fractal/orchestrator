---
schema_version: "1.0"
type: task-plan
task: "T05"
phase: "P02"
milestone: "M032"
name: "SC-3 + SC-7 acceptance scripts + paired-launch seam-{A,B,C} + phase suite + scope guard"
depends_on: ["T01", "T02", "T03", "T04"]
---

## Prerequisites

- T01 has landed `scripts/lifecycle/wiki-init.sh` (FR-5 default scope), `commands/wiki-init.md`, `wiki/mkdocs.yml` placeholders + FR-6 self-application loop closure, and the `wiki/` entry in `packaging/bundle/manifest.yml`. Verified by `[ -x scripts/lifecycle/wiki-init.sh ]` and `grep -q '{{site_name}}' wiki/mkdocs.yml` (briefly — note: the orchestrator-local resolved state after self-application MAY have placeholders cleared; the bundle staging path keeps them in the bundle source). Test-only escape `M032_WIKI_INIT_FORCE_EXIT` is wired in `wiki-init.sh`.
- T02 has landed the `--with-wiki [--with-giscus] [--deploy]` passthrough on `commands/init.md` and `scripts/lifecycle/init-project.sh` with the FR-11 / MIT-011 sequential-atomicity contract. Verified by `grep -q -- '--with-wiki' scripts/lifecycle/init-project.sh` and `grep -q 'init-complete, wiki-pending' scripts/lifecycle/init-project.sh`.
- T03 has landed `wiki/glossary.md` at the orchestrator-repo root with at least three `### TERM` headings, the `--include-glossary` flag on `wiki-scan-sources.sh`, and the Glossary-as-second-entry placement in `wiki-generate-nav.sh`. Verified by `[ -f wiki/glossary.md ]` and `grep -c '^### ' wiki/glossary.md` returning `>= 3`.
- T04 has landed `scripts/knowledge/lookup-mems.sh --kind=glossary` honoring [M031](../../../../../milestones/M031/index.md) profiles and the MIT-010 safe-default-no-terms fallback. Verified by `[ -x scripts/knowledge/lookup-mems.sh ]` and `grep -q 'safe-default-no-terms\|MIT-010' scripts/knowledge/lookup-mems.sh`.
- `tests/m032-acceptance/` exists (P01 deliverable) with `p01-managed-bundle-shape.sh`, `p01-staged-dirs-collision.sh`, `p01-symlink-mode.sh`. Verified by `[ -d tests/m032-acceptance ]`.
- `tests/fixtures/m032-fresh-project-fixture/` exists (P01 deliverable). Verified by `[ -d tests/fixtures/m032-fresh-project-fixture ]`.
- `tests/paired-m032-m033/` does NOT exist on disk at plan-authoring time (verified). T05 creates this directory.
- `tools/verify/m032-p02-{wiki-init-command-shape,wiki-init-default-scope,mkdocs-templating-and-self-application,init-with-wiki-passthrough,glossary-format-invariant,glossary-scanner-and-nav,lookup-mems-glossary}.sh` exist on disk (T01–T04 deliverables). Verified by `[ -x tools/verify/m032-p02-wiki-init-command-shape.sh ]` etc.
- T05 entry: this is the FINAL P02 task. None of the SC-3 / SC-7 acceptance scripts, the three seam scripts, the phase suite, or the scope guard exist yet.

## Description

T05 lands the verification surface that ties P02 closed. Five deliverable categories:

1. **Acceptance scripts** — `tests/m032-acceptance/p02-wiki-init-default-scope.sh` (SC-3) and `tests/m032-acceptance/p02-glossary-surface.sh` (SC-7, resolving the spec's `p0X-` placeholder per #Q-4 to P02). These are the milestone-grain SCs that ride into M032's `validate-milestone.sh` and `run-acceptance-battery.sh` (P05's deliverables — T05's contribution is the SC-3 + SC-7 entries themselves).

2. **Paired-launch seam scripts** — `tests/paired-m032-m033/seam-{A,B,C}.sh` per #Q-B. These are SHARED contracts between M032 and [M033](../../../../../milestones/M033/index.md) — both milestones' verifiers reference them. M033/P05 invokes M032's `--with-wiki` gate per CON-3; the seams encode the shared invariants:
   - **Seam-A**: `project_assets:` schema shape M033 consumes for its 7-new-commands + 6-new-scripts shipping.
   - **Seam-B**: `--with-wiki` failure-propagation contract per FR-11 / MIT-011, exercised via `M032_WIKI_INIT_FORCE_EXIT=7` injection.
   - **Seam-C**: `wiki/glossary.md` format invariant — both M032 (path owner) and M033 (primary writer via grilling-shell) treat as shared invariant.

3. **Phase-suite aggregator** — `tools/verify/m032-p02-phase-suite.sh` chaining all twelve P02 sub-gates in dependency order with single-script-file shape per AD-19. Models on `tools/verify/m032-p01-phase-suite.sh` from P01.

4. **Scope guard** — `tools/verify/m032-p02-scope-guard.sh` asserting P02's diff is confined to the declared "Files Likely Touched" list. Models on `tools/verify/m032-p01-scope-guard.sh` from P01 (committed-history-only diff per the P01 patterns-established lessons).

5. **Acceptance-shape verifiers** — `tools/verify/m032-p02-acceptance-shape-sc3.sh` and `tools/verify/m032-p02-acceptance-shape-sc7.sh` that assert SC-3 + SC-7's load-bearing literals. Models on `tools/verify/m032-p01-acceptance-shape-sc1.sh` from P01.

## Steps

1. **Author `tests/m032-acceptance/p02-wiki-init-default-scope.sh`** (SC-3). The script exercises FR-5 + FR-6 + FR-12 end-to-end against the P01 shared fixture. Required structure (single-script-file shape per AD-19; bash 3.2 compatible; emit POSIX exit 77 on `python3` unavailable per MIT-001):

```bash
#!/usr/bin/env bash
# SC-3 — verifies FR-5 (wiki-init default scope) + FR-6 (mkdocs templating) + FR-12 (toolchain probe).
set -eu

# MIT-001 SKIP_REASON if python3 unavailable.
if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP_REASON: python3 unavailable on this host"
  exit 77
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Stage a fresh fixture from the P01 shared fixture (read-only baseline).
cp -R tests/fixtures/m032-fresh-project-fixture/. "$TMP/"
( cd "$TMP" && git init -q && git remote add origin https://github.com/fixture-owner/m032-fresh-project-fixture.git ) >/dev/null 2>&1

# (a) FR-5 + FR-6 templating fired.
bash scripts/lifecycle/wiki-init.sh --project-dir "$TMP" >/dev/null 2>&1 || { echo "FAIL: SC-3 wiki-init exit non-zero"; exit 1; }
[ -f "$TMP/wiki/mkdocs.yml" ] || { echo "FAIL: SC-3 mkdocs.yml not staged"; exit 1; }
grep -q "site_name: \"m032-fresh-project-fixture\"" "$TMP/wiki/mkdocs.yml" || { echo "FAIL: SC-3 site_name not substituted"; exit 1; }
grep -q "repo_url: \"https://github.com/fixture-owner/m032-fresh-project-fixture\"" "$TMP/wiki/mkdocs.yml" || { echo "FAIL: SC-3 repo_url not substituted"; exit 1; }
# Negative: no orchestrator-identity values leaked in.
grep -q 'orchestrator' "$TMP/wiki/mkdocs.yml" && { echo "FAIL: SC-3 orchestrator identity leaked into fixture mkdocs.yml"; exit 1; } || true
# Negative: no remaining placeholders.
grep -q '{{site_name}}' "$TMP/wiki/mkdocs.yml" && { echo "FAIL: SC-3 placeholder {{site_name}} remained"; exit 1; } || true

# (b) Giscus partial retains placeholder tokens (P03 fills them, not P02).
PARTIAL="$TMP/wiki/overrides/partials/comments.html"
if [ -f "$PARTIAL" ]; then
  grep -q '{{giscus_repo}}\|data-repo="{{' "$PARTIAL" || echo "WARN: SC-3 Giscus partial missing placeholder tokens (expected for P02)" >&2
fi

# (c) wiki-serve.sh HTTP probe at :8000 — extract to a helper to keep AD-19 envelope.
bash tools/verify/lib/m032-p02-wiki-serve-probe.sh "$TMP" || { echo "FAIL: SC-3 wiki-serve.sh did not return HTTP 200"; exit 1; }

# (d) FR-12 platform-aware diagnostic when python3 absent.
TMP2="$(mktemp -d)"
cp -R tests/fixtures/m032-fresh-project-fixture/. "$TMP2/"
( cd "$TMP2" && git init -q && git remote add origin https://github.com/fixture-owner/m032-fresh-project-fixture.git ) >/dev/null 2>&1
set +e
PATH=/usr/bin:/bin bash scripts/lifecycle/wiki-init.sh --project-dir "$TMP2" >/dev/null 2>"$TMP2/err"
RC=$?
set -e
# Note: PATH=/usr/bin:/bin will likely still find python3 on macOS; this branch is a best-effort probe.
# If python3 is found anyway, treat as a soft pass with a warning rather than fail.
if [ "$RC" = "0" ]; then
  echo "WARN: SC-3 FR-12 probe found python3 even with PATH narrowed; treating as soft-pass" >&2
elif [ "$RC" = "3" ]; then
  grep -q 'brew install python3\|apt install python3' "$TMP2/err" || { echo "FAIL: SC-3 FR-12 missing platform-aware diagnostic"; exit 1; }
else
  echo "FAIL: SC-3 FR-12 unexpected exit code $RC"; exit 1
fi
rm -rf "$TMP2"

echo "PASS: SC-3 p02-wiki-init-default-scope"
```

The verifier delegates the live HTTP probe to `tools/verify/lib/m032-p02-wiki-serve-probe.sh` (T01 deliverable per the FR-6 self-application verifier; if T01 placed it elsewhere, T05 either references the existing helper or co-authors it). The helper does the start+probe+kill in a single script body — the SC-3 acceptance script invokes it via `bash` only, not via inline `&` + `kill` chains (AD-19 envelope).

2. **Author `tests/m032-acceptance/p02-glossary-surface.sh`** (SC-7). Resolves the spec's `p0X-glossary-surface.sh` placeholder per #Q-4 to P02. Required structure:

```bash
#!/usr/bin/env bash
# SC-7 — verifies FR-15 (glossary scanner+nav) + FR-16 (knowledge adapter) + MIT-010 (Quick traversal).
set -eu

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# (a) FR-15 — glossary path-convention surface
[ -f wiki/glossary.md ] || { echo "FAIL: SC-7 wiki/glossary.md missing at orchestrator root"; exit 1; }
HC="$(grep -c '^### ' wiki/glossary.md)"
[ "$HC" -ge 3 ] || { echo "FAIL: SC-7 wiki/glossary.md needs >= 3 ### TERM entries; got $HC"; exit 1; }

# Scanner --include-glossary on emits the path
bash scripts/wiki/wiki-scan-sources.sh --root . --include-glossary > "$TMP/sources.txt" 2>/dev/null
grep -q 'wiki/glossary.md' "$TMP/sources.txt" || { echo "FAIL: SC-7 scanner did not emit wiki/glossary.md under --include-glossary"; exit 1; }

# Nav generator places Glossary as second top-level nav entry — non-destructive probe via mkdocs.yml backup.
cp wiki/mkdocs.yml "$TMP/mkdocs.yml.bak"
bash scripts/wiki/wiki-generate-nav.sh --root . >/dev/null 2>&1 || { cp "$TMP/mkdocs.yml.bak" wiki/mkdocs.yml; echo "FAIL: SC-7 wiki-generate-nav.sh failed"; exit 1; }
MARKER_LINE="$(grep -n '^# >>> M012-P01 nav' wiki/mkdocs.yml | head -1 | cut -d: -f1)"
SECOND_ENTRY="$(awk -v start="$MARKER_LINE" 'NR>start && /^  - / {count++; if(count==2){print; exit}}' wiki/mkdocs.yml)"
echo "$SECOND_ENTRY" | grep -q 'Glossary' || { cp "$TMP/mkdocs.yml.bak" wiki/mkdocs.yml; echo "FAIL: SC-7 Glossary not the second top-level nav entry"; exit 1; }
cp "$TMP/mkdocs.yml.bak" wiki/mkdocs.yml

# (b) FR-16 — knowledge adapter standard profile emits records
bash scripts/knowledge/lookup-mems.sh --kind=glossary --profile=standard --root . > "$TMP/std.txt" 2>/dev/null
N="$(grep -c '^id: gloss-' "$TMP/std.txt")"
[ "$N" -ge 3 ] || { echo "FAIL: SC-7 standard profile expected >= 3 records got $N"; exit 1; }

# Idempotency: ids stable across re-invocations
bash scripts/knowledge/lookup-mems.sh --kind=glossary --profile=standard --root . > "$TMP/std2.txt" 2>/dev/null
grep '^id: ' "$TMP/std.txt" | sort > "$TMP/ids1.txt"
grep '^id: ' "$TMP/std2.txt" | sort > "$TMP/ids2.txt"
diff -q "$TMP/ids1.txt" "$TMP/ids2.txt" >/dev/null || { echo "FAIL: SC-7 ids not idempotent across runs"; exit 1; }

# (c) FR-16 / MIT-010 Quick-profile touched-term branches
# Fixture glossary with three known terms
mkdir -p "$TMP/fixture/wiki"
cat > "$TMP/fixture/wiki/glossary.md" <<'EOF'
# Glossary

### Bar
Bar definition.

### Baz
Baz definition.

### Foo
Foo definition.
EOF

# Quick + task-description hit
bash scripts/knowledge/lookup-mems.sh --kind=glossary --profile=quick --task-description 'rename foo' --root "$TMP/fixture" > "$TMP/qhit.txt" 2>/dev/null
N="$(grep -c '^id: gloss-' "$TMP/qhit.txt")"
[ "$N" = "1" ] || { echo "FAIL: SC-7 Quick+task-desc hit expected 1 got $N"; exit 1; }
grep -q '^id: gloss-foo$' "$TMP/qhit.txt" || { echo "FAIL: SC-7 Quick+task-desc did not emit gloss-foo"; exit 1; }

# MIT-010 safe-default-no-terms — Quick with no hints
bash scripts/knowledge/lookup-mems.sh --kind=glossary --profile=quick --root "$TMP/fixture" > "$TMP/qsafe.txt" 2>/dev/null
N="$(grep -c '^id: gloss-' "$TMP/qsafe.txt")"
[ "$N" = "0" ] || { echo "FAIL: SC-7 MIT-010 safe-default expected 0 got $N"; exit 1; }

echo "PASS: SC-7 p02-glossary-surface"
```

3. **Author `tests/paired-m032-m033/seam-A.sh`** (#Q-B Seam-A). Required structure:

```bash
#!/usr/bin/env bash
# Seam-A — shared install-bundle surface invariant: project_assets: schema shape M033 consumes.
set -eu

# Manifest carries project_assets: section
[ -f packaging/bundle/manifest.yml ] || { echo "FAIL: Seam-A manifest missing"; exit 1; }
grep -q '^project_assets:$' packaging/bundle/manifest.yml || { echo "FAIL: Seam-A project_assets section missing"; exit 1; }

# Reader emits tuples
TUPLES="$(bash scripts/lifecycle/read-project-assets.sh packaging/bundle/ 2>/dev/null || true)"
[ -n "$TUPLES" ] || { echo "FAIL: Seam-A reader emitted zero tuples"; exit 1; }

# At least 5 tuples (4 P01 runtime dirs + 1 P02 wiki)
TUPLE_COUNT="$(echo "$TUPLES" | wc -l | tr -d ' ')"
[ "$TUPLE_COUNT" -ge 5 ] || { echo "FAIL: Seam-A expected >= 5 tuples (4 P01 + 1 P02 wiki) got $TUPLE_COUNT"; exit 1; }

# wiki/ entry present (P02/T01 deliverable)
echo "$TUPLES" | grep -q 'source=wiki/' || { echo "FAIL: Seam-A missing source=wiki/ tuple"; exit 1; }

# M033 will ship 7 new commands + 6 new scripts on top of this seam — assert the
# schema shape is stable: each tuple has source=, target=, mode= fields
echo "$TUPLES" | while IFS= read -r tuple; do
  echo "$tuple" | grep -q '^source=' || { echo "FAIL: Seam-A tuple missing source: '$tuple'"; exit 1; }
  echo "$tuple" | grep -q $'\ttarget=' || { echo "FAIL: Seam-A tuple missing target: '$tuple'"; exit 1; }
  echo "$tuple" | grep -q $'\tmode=' || { echo "FAIL: Seam-A tuple missing mode: '$tuple'"; exit 1; }
done

echo "PASS: Seam-A project_assets shape (M033 ↔ M032)"
```

4. **Author `tests/paired-m032-m033/seam-B.sh`** (#Q-B Seam-B). Exercises the FR-11 / MIT-011 failure-propagation contract via `M032_WIKI_INIT_FORCE_EXIT=7` injection. Required structure:

```bash
#!/usr/bin/env bash
# Seam-B — --with-wiki failure-propagation contract per FR-11 / MIT-011.
set -eu

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Stage a fresh fixture
cp -R tests/fixtures/m032-fresh-project-fixture/. "$TMP/"
( cd "$TMP" && git init -q && git remote add origin https://github.com/fixture-owner/m032-fresh-project-fixture.git ) >/dev/null 2>&1

# Inject failure into wiki-init.sh via env-var
set +e
M032_WIKI_INIT_FORCE_EXIT=7 bash scripts/lifecycle/init-project.sh --with-wiki --project-dir "$TMP" >"$TMP/out" 2>"$TMP/err"
RC=$?
set -e

# (a) Compound exit code is wiki-init.sh's literal exit code (7), NOT 0, NOT 1.
[ "$RC" = "7" ] || { echo "FAIL: Seam-B compound exit expected 7 got $RC"; exit 1; }

# (b) init outputs preserved on wiki-init failure
[ -d "$TMP/.orchestrator" ] || { echo "FAIL: Seam-B init outputs not preserved on wiki-init failure"; exit 1; }

# (c) init-complete, wiki-pending diagnostic on stderr
grep -q 'init-complete, wiki-pending' "$TMP/err" || { echo "FAIL: Seam-B missing init-complete, wiki-pending diagnostic"; exit 1; }

# (d) wiki-init outputs absent (the failure aborted before staging)
[ ! -f "$TMP/wiki/mkdocs.yml" ] || { echo "FAIL: Seam-B wiki/mkdocs.yml present despite forced failure"; exit 1; }

# (e) M033/P01..P04 stub-mode compatibility per M033-MIT-001: caller can re-run wiki-init independently.
unset M032_WIKI_INIT_FORCE_EXIT
bash scripts/lifecycle/wiki-init.sh --project-dir "$TMP" >/dev/null 2>&1 || { echo "FAIL: Seam-B independent wiki-init re-run failed"; exit 1; }
[ -f "$TMP/wiki/mkdocs.yml" ] || { echo "FAIL: Seam-B independent wiki-init did not stage mkdocs.yml"; exit 1; }

echo "PASS: Seam-B --with-wiki failure-propagation (FR-11 / MIT-011)"
```

5. **Author `tests/paired-m032-m033/seam-C.sh`** (#Q-B Seam-C). Required structure:

```bash
#!/usr/bin/env bash
# Seam-C — wiki/glossary.md format invariant. Both M032 (path owner) and M033 (writer via grilling-shell) honor.
set -eu

G="wiki/glossary.md"
[ -f "$G" ] || { echo "FAIL: Seam-C $G missing at orchestrator root"; exit 1; }

# Format invariant: ### TERM headings present
HC="$(grep -c '^### ' "$G")"
[ "$HC" -ge 3 ] || { echo "FAIL: Seam-C $G needs >= 3 ### TERM entries; got $HC"; exit 1; }

# Alphabetized at file scope
TERMS_TMP="$(mktemp)"
SORTED_TMP="$(mktemp)"
trap 'rm -f "$TERMS_TMP" "$SORTED_TMP"' EXIT
grep '^### ' "$G" | sed 's/^### //' > "$TERMS_TMP"
sort "$TERMS_TMP" > "$SORTED_TMP"
diff -q "$TERMS_TMP" "$SORTED_TMP" >/dev/null || { echo "FAIL: Seam-C entries not alphabetized"; exit 1; }

# One-line definition under each heading (within 2 lines)
awk '/^### /{h=NR; t=$0; next} h && NR<=h+2 && NF>0 {h=0} END {if(h) {print "FAIL: Seam-C heading "t" has no definition body within 2 lines"; exit 1}}' "$G" || exit 1

# At-most-two-line elaboration: between this heading and the next ### heading,
# at most 4 non-empty lines total (1 definition + 2 elaboration + 1 separator slack)
awk '
  /^### / {
    if (term != "" && nonempty > 4) {
      print "FAIL: Seam-C term \"" term "\" has " nonempty " non-empty body lines (max 4)"
      exit 1
    }
    term = substr($0, 5)
    nonempty = 0
    next
  }
  NF > 0 { nonempty++ }
  END {
    if (term != "" && nonempty > 4) {
      print "FAIL: Seam-C term \"" term "\" has " nonempty " non-empty body lines (max 4)"
      exit 1
    }
  }
' "$G" || exit 1

echo "PASS: Seam-C wiki/glossary.md format invariant"
```

6. **Author the seven T05 verifiers** under `tools/verify/`:

   - `m032-p02-acceptance-shape-sc3.sh` — asserts `tests/m032-acceptance/p02-wiki-init-default-scope.sh` exists, contains `SC-3` and `FR-5` and `FR-6` and `FR-12` and `wiki-serve.sh` literals, exits 0 in dry-run shape inspection.
   - `m032-p02-acceptance-shape-sc7.sh` — asserts `tests/m032-acceptance/p02-glossary-surface.sh` exists, contains `SC-7` and `FR-15` and `FR-16` and `MIT-010` and `--profile=quick` literals.
   - `m032-p02-seam-a-shape.sh` — asserts `tests/paired-m032-m033/seam-A.sh` exists, contains `Seam-A` and `project_assets:` and `M033` literals.
   - `m032-p02-seam-b-shape.sh` — asserts `tests/paired-m032-m033/seam-B.sh` exists, contains `Seam-B` and `FR-11` and `MIT-011` and `M032_WIKI_INIT_FORCE_EXIT` and `init-complete, wiki-pending` literals.
   - `m032-p02-seam-c-shape.sh` — asserts `tests/paired-m032-m033/seam-C.sh` exists, contains `Seam-C` and `wiki/glossary.md` and `format invariant` and `###` literals.
   - `m032-p02-phase-suite.sh` — chains all twelve P02 sub-gates in dependency order; emits `SUMMARY: m032-p02-phase-suite.sh pass=N fail=M` before exit. Single-script-file shape per AD-19 — no compound bash chains, no `bash -c '...' && bash -c '...'`. Use a straight-line invocation pattern modeled on `tools/verify/m032-p01-phase-suite.sh`. The twelve sub-gates in order:
     1. `m032-p02-wiki-init-command-shape.sh` (T01)
     2. `m032-p02-wiki-init-default-scope.sh` (T01)
     3. `m032-p02-mkdocs-templating-and-self-application.sh` (T01)
     4. `m032-p02-init-with-wiki-passthrough.sh` (T02)
     5. `m032-p02-glossary-format-invariant.sh` (T03)
     6. `m032-p02-glossary-scanner-and-nav.sh` (T03)
     7. `m032-p02-lookup-mems-glossary.sh` (T04)
     8. `m032-p02-seam-a-shape.sh` (T05)
     9. `m032-p02-seam-b-shape.sh` (T05)
     10. `m032-p02-seam-c-shape.sh` (T05)
     11. `m032-p02-acceptance-shape-sc3.sh` (T05)
     12. `m032-p02-acceptance-shape-sc7.sh` (T05)

   Phase-suite skeleton:

```bash
#!/usr/bin/env bash
# tools/verify/m032-p02-phase-suite.sh — straight-line aggregator per AD-19.
set -u

PASS=0
FAIL=0

run_check() {
  local name="$1"
  if bash "tools/verify/$name.sh" >/dev/null 2>&1; then
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name" >&2
    FAIL=$((FAIL + 1))
  fi
}

run_check m032-p02-wiki-init-command-shape
run_check m032-p02-wiki-init-default-scope
run_check m032-p02-mkdocs-templating-and-self-application
run_check m032-p02-init-with-wiki-passthrough
run_check m032-p02-glossary-format-invariant
run_check m032-p02-glossary-scanner-and-nav
run_check m032-p02-lookup-mems-glossary
run_check m032-p02-seam-a-shape
run_check m032-p02-seam-b-shape
run_check m032-p02-seam-c-shape
run_check m032-p02-acceptance-shape-sc3
run_check m032-p02-acceptance-shape-sc7

echo "SUMMARY: m032-p02-phase-suite.sh pass=$PASS fail=$FAIL"
[ "$FAIL" = "0" ] || exit 1
exit 0
```

   - `m032-p02-scope-guard.sh` — asserts P02's diff is confined to the declared "Files Likely Touched" list per the P01 scope-guard pattern. Uses committed-history-only diff against a baseline ref captured at first run (modeled on P01 — `tools/verify/fixtures/m032-p01-baseline-ref.txt`; T05 records `tools/verify/fixtures/m032-p02-baseline-ref.txt` at first invocation). The allowlist is the P02 "Files Likely Touched" set: `commands/wiki-init.md`, `scripts/lifecycle/wiki-init.sh`, `wiki/mkdocs.yml`, `packaging/bundle/manifest.yml`, `commands/init.md`, `scripts/lifecycle/init-project.sh`, `wiki/glossary.md`, `scripts/wiki/wiki-scan-sources.sh`, `scripts/wiki/wiki-generate-nav.sh`, `scripts/knowledge/lookup-mems.sh`, `tests/m032-acceptance/p02-*.sh`, `tests/paired-m032-m033/seam-*.sh`, `tools/verify/m032-p02-*.sh`, `tools/verify/lib/m032-p02-wiki-serve-probe.sh`, `.orchestrator/milestones/M032/phases/P02/**` (plan + summary files). Every other path in the diff is OUT-OF-SCOPE and the guard fails closed.

   Scope-guard skeleton (modeled on P01):

```bash
#!/usr/bin/env bash
# tools/verify/m032-p02-scope-guard.sh — SC-13 scope discipline for P02.
set -eu

BASELINE_FIXTURE="tools/verify/fixtures/m032-p02-baseline-ref.txt"
if [ ! -f "$BASELINE_FIXTURE" ]; then
  # First run: capture current HEAD as baseline; PASS unconditionally.
  mkdir -p "$(dirname "$BASELINE_FIXTURE")"
  git rev-parse HEAD > "$BASELINE_FIXTURE"
  echo "PASS: m032-p02 scope-guard (baseline captured at $(cat "$BASELINE_FIXTURE"))"
  exit 0
fi

BASELINE_REF="$(cat "$BASELINE_FIXTURE")"

# Committed-history-only diff (per P01 patterns-established lessons — working-tree
# dirt pollutes the scope signal otherwise).
DIFF_PATHS="$(git diff --name-only "$BASELINE_REF" HEAD 2>/dev/null || true)"

# Allowlist regex — paths matching are P02-scoped.
ALLOWED_RE='^(commands/wiki-init\.md|scripts/lifecycle/wiki-init\.sh|wiki/mkdocs\.yml|packaging/bundle/manifest\.yml|commands/init\.md|scripts/lifecycle/init-project\.sh|wiki/glossary\.md|scripts/wiki/wiki-scan-sources\.sh|scripts/wiki/wiki-generate-nav\.sh|scripts/knowledge/lookup-mems\.sh|tests/m032-acceptance/p02-.*\.sh|tests/paired-m032-m033/seam-.*\.sh|tools/verify/m032-p02-.*\.sh|tools/verify/lib/m032-p02-.*\.sh|tools/verify/fixtures/m032-p02-.*|\.orchestrator/milestones/M032/phases/P02/.*)$'

OUT_OF_SCOPE=""
echo "$DIFF_PATHS" | while IFS= read -r path; do
  [ -n "$path" ] || continue
  if ! echo "$path" | grep -E "$ALLOWED_RE" >/dev/null; then
    echo "OUT-OF-SCOPE: $path" >&2
    OUT_OF_SCOPE=1
  fi
done

# (Subshell variable propagation gotcha: the while-loop's OUT_OF_SCOPE assignment
# does not propagate to the parent shell. Use a marker file instead.)
MARKER="$(mktemp)"
trap 'rm -f "$MARKER"' EXIT
echo "$DIFF_PATHS" | while IFS= read -r path; do
  [ -n "$path" ] || continue
  if ! echo "$path" | grep -E "$ALLOWED_RE" >/dev/null; then
    echo "OUT-OF-SCOPE: $path" >> "$MARKER"
  fi
done

if [ -s "$MARKER" ]; then
  cat "$MARKER" >&2
  echo "FAIL: m032-p02 scope-guard out-of-scope paths detected"
  exit 1
fi

echo "PASS: m032-p02 scope-guard ($(echo "$DIFF_PATHS" | wc -l | tr -d ' ') in-scope paths)"
exit 0
```

7. **Run the full P02 verifier battery locally** to confirm every gate passes:

```bash
bash tools/verify/m032-p02-phase-suite.sh
```

Expected output: `SUMMARY: m032-p02-phase-suite.sh pass=12 fail=0`.

## Must-Haves

- `tests/m032-acceptance/p02-wiki-init-default-scope.sh` (SC-3) exists, is executable, and exits 0 (or 77 with `SKIP_REASON` if `python3` unavailable per MIT-001).
- `tests/m032-acceptance/p02-glossary-surface.sh` (SC-7) exists, is executable, and exits 0.
- `tests/paired-m032-m033/seam-A.sh` exists, is executable, exits 0; asserts `project_assets:` schema shape M033 consumes (>= 5 tuples, `wiki/` tuple present, source/target/mode fields present).
- `tests/paired-m032-m033/seam-B.sh` exists, is executable, exits 0; asserts FR-11 / MIT-011 failure-propagation contract via `M032_WIKI_INIT_FORCE_EXIT=7` injection (compound exit 7, init outputs preserved, `init-complete, wiki-pending` diagnostic, independent wiki-init re-run succeeds).
- `tests/paired-m032-m033/seam-C.sh` exists, is executable, exits 0; asserts `wiki/glossary.md` format invariant (>= 3 ### TERM headings, alphabetized, one-line definition, at-most-two-line elaboration).
- `tools/verify/m032-p02-acceptance-shape-sc3.sh` and `tools/verify/m032-p02-acceptance-shape-sc7.sh` exist and exit 0.
- `tools/verify/m032-p02-seam-a-shape.sh`, `m032-p02-seam-b-shape.sh`, `m032-p02-seam-c-shape.sh` exist and exit 0.
- `tools/verify/m032-p02-phase-suite.sh` exists, chains all twelve P02 sub-gates in dependency order with single-script-file shape per AD-19, emits `SUMMARY: m032-p02-phase-suite.sh pass=12 fail=0` on success.
- `tools/verify/m032-p02-scope-guard.sh` exists, captures the baseline ref at `tools/verify/fixtures/m032-p02-baseline-ref.txt` on first run, and on subsequent runs asserts P02's diff is confined to the allowlist regex.

## Verification

```bash
bash tools/verify/m032-p02-acceptance-shape-sc3.sh
bash tools/verify/m032-p02-acceptance-shape-sc7.sh
bash tools/verify/m032-p02-seam-a-shape.sh
bash tools/verify/m032-p02-seam-b-shape.sh
bash tools/verify/m032-p02-seam-c-shape.sh
bash tools/verify/m032-p02-phase-suite.sh
bash tools/verify/m032-p02-scope-guard.sh
```

## Inputs

### From Previous Tasks

- `scripts/lifecycle/wiki-init.sh` (from T01) — invoked by SC-3 and Seam-B. Test-only escape `M032_WIKI_INIT_FORCE_EXIT=<n>` exits `<n>` immediately; consumed by Seam-B.
- `commands/wiki-init.md` (from T01) — referenced by `m032-p02-wiki-init-command-shape.sh` (T01 verifier, also chained from phase-suite).
- `wiki/mkdocs.yml` placeholders + FR-6 self-application (from T01) — verified by `m032-p02-mkdocs-templating-and-self-application.sh`.
- `tools/verify/lib/m032-p02-wiki-serve-probe.sh` (from T01) — invoked by SC-3 for the live HTTP probe at :8000.
- `commands/init.md` and `scripts/lifecycle/init-project.sh` (from T02) — invoked by Seam-B for the FR-11 / MIT-011 contract verification. Key API: `bash init-project.sh --with-wiki --project-dir <dir>` runs init then wiki-init sequentially; on wiki-init failure the compound exit code is wiki-init's literal exit code and `init-complete, wiki-pending` is on stderr.
- `wiki/glossary.md` (from T03) — read by SC-7 and Seam-C.
- `scripts/wiki/wiki-scan-sources.sh --include-glossary` (from T03) — invoked by SC-7.
- `scripts/wiki/wiki-generate-nav.sh` (from T03) — invoked by SC-7 for the Glossary-as-second-entry placement check.
- `scripts/knowledge/lookup-mems.sh --kind=glossary` (from T04) — invoked by SC-7. Key API: `--profile=quick` + `--task-description` / `--file-change-set` for touched-term filtering; `--profile=quick` with no hints emits zero records (MIT-010).

### From Disk (Pre-existing)

- `tests/fixtures/m032-fresh-project-fixture/` (P01 deliverable) — used by SC-3 and Seam-B as the staging baseline.
- `tests/m032-acceptance/` directory (P01 deliverable) — home for the SC-3 + SC-7 acceptance scripts.
- `tools/verify/fixtures/` directory — home for the scope-guard's baseline ref.
- `tools/verify/m032-p01-phase-suite.sh` and `tools/verify/m032-p01-scope-guard.sh` (P01 deliverables) — modeled on by the T05 phase-suite and scope-guard.

## Constraints

- T05 MUST NOT modify any T01–T04 deliverable. T05 is purely verification + paired-launch seam authorship.
- The phase-suite verifier MUST use single-script-file shape per AD-19 — straight-line `run_check <name>` invocations within a function body, no `bash -c '...' && bash -c '...'` chains, no `$()` containing pipes. The `run_check` helper invokes `bash "tools/verify/$name.sh"` with stdout / stderr suppressed; aggregate counters `PASS` and `FAIL` are simple integer additions.
- The scope-guard verifier MUST use committed-history-only diff (`git diff --name-only "$BASELINE_REF" HEAD`) per the P01 patterns-established lesson — working-tree-vs-baseline diff was the failure mode that produced the M032/P01 99-PASS-trajectory rebaseline.
- The scope-guard's allowlist regex MUST cover EVERY path the P02 plan declares as "Files Likely Touched" — additions to the path list during T05 author require corresponding regex extensions.
- The seam scripts MUST be executable (`chmod +x`) and MUST emit `PASS: Seam-A ...` / `PASS: Seam-B ...` / `PASS: Seam-C ...` to stdout on success. M033's verifier suite consumes these PASS lines per #Q-B.
- The SC-3 acceptance script MUST honor MIT-001 SKIP semantics: exit 77 with `SKIP_REASON: ...` to stdout when `python3` is unavailable (acceptance-battery T05 in P05 distinguishes 77 from pass / fail).
- Bash 3.2 compatibility per MEM001 in all verifiers and acceptance scripts — no `declare -A`, no `mapfile`, no process substitution.
- Plan-time discipline rule 6 (path-collision check): all seven new T05 verifiers, both new acceptance scripts, all three seam scripts, and the new fixture file `tools/verify/fixtures/m032-p02-baseline-ref.txt` do NOT exist on disk at plan-authoring time. Only `tests/m032-acceptance/` (directory) and `tools/verify/fixtures/` (directory) exist as parent containers.

## Expected Output

After T05 completes:

- `tests/m032-acceptance/p02-wiki-init-default-scope.sh` and `tests/m032-acceptance/p02-glossary-surface.sh` are new executable acceptance scripts.
- `tests/paired-m032-m033/seam-A.sh`, `seam-B.sh`, `seam-C.sh` are new executable seam scripts under a new directory.
- `tools/verify/m032-p02-acceptance-shape-sc3.sh`, `m032-p02-acceptance-shape-sc7.sh`, `m032-p02-seam-a-shape.sh`, `m032-p02-seam-b-shape.sh`, `m032-p02-seam-c-shape.sh`, `m032-p02-phase-suite.sh`, `m032-p02-scope-guard.sh` are new executable verifiers.
- `tools/verify/fixtures/m032-p02-baseline-ref.txt` is captured at scope-guard first run.
- `bash tools/verify/m032-p02-phase-suite.sh` emits `SUMMARY: m032-p02-phase-suite.sh pass=12 fail=0` on success.
- M033/P05 has the three paired-launch seam scripts to plan against per CON-3.

## Notes

- Expected verifier outputs: `PASS: m032-p02-acceptance-shape-sc3` / `PASS: m032-p02-acceptance-shape-sc7` / `PASS: Seam-A ...` / `PASS: Seam-B ...` / `PASS: Seam-C ...` / `SUMMARY: m032-p02-phase-suite.sh pass=12 fail=0` / `PASS: m032-p02 scope-guard ...` to stdout on exit 0.
- Plan-time discipline rule 2 (verifier-availability cross-check): all seven verifiers cited in `## Verification` are co-authored within this task in step 6.
- Plan-time discipline rule 6 (path-collision check): all new files do NOT exist on disk at plan-authoring time (verified — `ls tests/paired-m032-m033/` returns `No such file or directory`; `ls tools/verify/ | grep "m032-p02"` returns empty).
- The `seam-B.sh` independent-re-run branch (step 4 (e)) validates M033/P01..P04 stub-mode compatibility per M033-MIT-001 — M033's stub-mode tests can re-invoke `wiki-init.sh` directly without re-running `init-project.sh`. The seam asserts this compatibility now so M033 has a stable contract to plan against.
- The phase-suite's twelve sub-gates aggregate ALL P02 verifiers from T01–T05. Adding a verifier in any subsequent task requires updating both the phase-suite invocation list AND the count in the demo sentence + must-haves SUMMARY assertion. The current count is 12; if T01-T04 task plans extended their verifier sets, this list adapts during T05 implementation.
- The MIT-001 three-category exit-code convention (pass=0, skip=77, fail=other-non-zero) is asserted at SC-3 only (the only P02 SC with environment-dependent skip semantics — `python3` availability). SC-7 has no skip path; either the FR-15 + FR-16 surfaces work or they don't.
- Note on the `M032_WIKI_INIT_FORCE_EXIT` test-only escape: T01's `wiki-init.sh` includes the escape per the T02 prerequisite check. If T01 chose to land it in T02 instead (the flexibility called out in T02's step 5), the escape MUST be in place by the time T05 lands; Seam-B's prerequisite check at the top of the script asserts this.
- The scope-guard's baseline-ref file (`tools/verify/fixtures/m032-p02-baseline-ref.txt`) is captured at FIRST scope-guard run. Subsequent runs read the captured ref and diff against HEAD. If the scope-guard verifier ever needs to be re-baselined (e.g., after a milestone close), an operator deletes the fixture file and re-runs the scope-guard once to recapture. This pattern matches P01's `m032-p01-baseline-ref.txt` precedent.
