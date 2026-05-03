#!/usr/bin/env bash
# tests/test-tier-1-adapters.sh -- M036 P01 SC-9 acceptance harness.
#
# Exercises all four Tier 1 live format adapters
# (scripts/dispatch/adapters/format/{markdown,pdf,docx,xlsx}.sh) against the
# real binary fixtures under tests/fixtures/m036-tier-1-adapters/. Per
# Plan-Time Discipline rule 5 (real-app smoke) and CON-3 amended (binary
# fixtures permitted under tests/fixtures/m036-tier-1-adapters/). No mocks
# at the adapter boundary.
#
# Host-tooling-aware: SKIPs the per-adapter case when its host tool is
# absent (matching the per-adapter verifier shape established by
# m036-p01-pdf-adapter.sh). SKIPs are NOT failures -- the harness exits 0
# iff fail=0 regardless of skip count, so a CI host without
# pandoc/openpyxl/pdftotext does not false-FAIL the suite.
#
# Output contract: one PASS:/FAIL:/SKIP: line per adapter case, followed by
# a final BATTERY: pass=<P> fail=<F> skip=<S> summary line. Consumers grep
# for "^BATTERY:" and parse the pass=/fail= fields explicitly.
#
# Bash 3.2 / POSIX-sh per CON-2. Single-script-file shape per AD-19 /
# AP-009 -- internal logic is sequential statements, no compound chains
# beyond the canonical 'if cmd; then ...' control-flow form.
set -eu

ROOT="${ORCHESTRATOR_ROOT:-$(pwd)}"
FIXDIR="$ROOT/tests/fixtures/m036-tier-1-adapters"

pass=0
fail=0
skip=0

# --- markdown -------------------------------------------------------------
MD_ADAPTER="$ROOT/scripts/dispatch/adapters/format/markdown.sh"
MD_FIXTURE="$FIXDIR/sample.md"
MD_OUT="${TMPDIR:-/tmp}/m036-sc9-md.$$.out"

if [ ! -f "$MD_ADAPTER" ]; then
  echo "FAIL: markdown adapter-missing ($MD_ADAPTER)"
  fail=$((fail + 1))
elif [ ! -f "$MD_FIXTURE" ]; then
  echo "FAIL: markdown fixture-missing ($MD_FIXTURE)"
  fail=$((fail + 1))
else
  set +e
  bash "$MD_ADAPTER" "$MD_FIXTURE" >"$MD_OUT" 2>/dev/null
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    echo "FAIL: markdown exit-0 (rc=$rc)"
    fail=$((fail + 1))
  elif diff -q "$MD_OUT" "$MD_FIXTURE" >/dev/null 2>&1; then
    echo "PASS: markdown byte-identical"
    pass=$((pass + 1))
  else
    echo "FAIL: markdown byte-identical (diff differed)"
    fail=$((fail + 1))
  fi
  rm -f "$MD_OUT"
fi

# --- pdf ------------------------------------------------------------------
PDF_ADAPTER="$ROOT/scripts/dispatch/adapters/format/pdf.sh"
PDF_FIXTURE="$FIXDIR/sample.pdf"
PDF_ALLOWLIST="$FIXDIR/expected/sample-pdf.txt"
PDF_OUT="${TMPDIR:-/tmp}/m036-sc9-pdf.$$.out"

if ! command -v pdftotext >/dev/null 2>&1; then
  echo "SKIP: pdf (pdftotext absent)"
  skip=$((skip + 1))
elif [ ! -f "$PDF_ADAPTER" ]; then
  echo "FAIL: pdf adapter-missing ($PDF_ADAPTER)"
  fail=$((fail + 1))
elif [ ! -f "$PDF_FIXTURE" ]; then
  echo "FAIL: pdf fixture-missing ($PDF_FIXTURE)"
  fail=$((fail + 1))
elif [ ! -f "$PDF_ALLOWLIST" ]; then
  echo "FAIL: pdf allowlist-missing ($PDF_ALLOWLIST)"
  fail=$((fail + 1))
else
  set +e
  bash "$PDF_ADAPTER" "$PDF_FIXTURE" >"$PDF_OUT" 2>/dev/null
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    echo "FAIL: pdf exit-0 (rc=$rc)"
    fail=$((fail + 1))
  elif [ ! -s "$PDF_OUT" ]; then
    echo "FAIL: pdf non-empty-output"
    fail=$((fail + 1))
  else
    missing=0
    while IFS= read -r token || [ -n "$token" ]; do
      case "$token" in
        ""|\#*) continue ;;
      esac
      if ! grep -q -F "$token" "$PDF_OUT"; then
        echo "FAIL: pdf token-$token (not found)"
        missing=$((missing + 1))
      fi
    done <"$PDF_ALLOWLIST"
    if [ "$missing" -eq 0 ]; then
      echo "PASS: pdf all-tokens-present"
      pass=$((pass + 1))
    else
      fail=$((fail + 1))
    fi
  fi
  rm -f "$PDF_OUT"
fi

# --- docx -----------------------------------------------------------------
DOCX_ADAPTER="$ROOT/scripts/dispatch/adapters/format/docx.sh"
DOCX_FIXTURE="$FIXDIR/sample.docx"
DOCX_ALLOWLIST="$FIXDIR/expected/sample-docx.txt"
DOCX_OUT="${TMPDIR:-/tmp}/m036-sc9-docx.$$.out"

if ! command -v pandoc >/dev/null 2>&1; then
  echo "SKIP: docx (pandoc absent)"
  skip=$((skip + 1))
elif [ ! -f "$DOCX_ADAPTER" ]; then
  echo "FAIL: docx adapter-missing ($DOCX_ADAPTER)"
  fail=$((fail + 1))
elif [ ! -f "$DOCX_FIXTURE" ]; then
  echo "FAIL: docx fixture-missing ($DOCX_FIXTURE)"
  fail=$((fail + 1))
elif [ ! -f "$DOCX_ALLOWLIST" ]; then
  echo "FAIL: docx allowlist-missing ($DOCX_ALLOWLIST)"
  fail=$((fail + 1))
else
  set +e
  bash "$DOCX_ADAPTER" "$DOCX_FIXTURE" >"$DOCX_OUT" 2>/dev/null
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    echo "FAIL: docx exit-0 (rc=$rc)"
    fail=$((fail + 1))
  elif [ ! -s "$DOCX_OUT" ]; then
    echo "FAIL: docx non-empty-output"
    fail=$((fail + 1))
  else
    missing=0
    while IFS= read -r token || [ -n "$token" ]; do
      case "$token" in
        ""|\#*) continue ;;
      esac
      if ! grep -q -F "$token" "$DOCX_OUT"; then
        echo "FAIL: docx token-$token (not found)"
        missing=$((missing + 1))
      fi
    done <"$DOCX_ALLOWLIST"
    if [ "$missing" -eq 0 ]; then
      echo "PASS: docx all-tokens-present"
      pass=$((pass + 1))
    else
      fail=$((fail + 1))
    fi
  fi
  rm -f "$DOCX_OUT"
fi

# --- xlsx -----------------------------------------------------------------
XLSX_ADAPTER="$ROOT/scripts/dispatch/adapters/format/xlsx.sh"
XLSX_FIXTURE="$FIXDIR/sample.xlsx"
XLSX_EXPECTED1="$FIXDIR/expected/sample-xlsx-sheet1.csv"
XLSX_EXPECTED2="$FIXDIR/expected/sample-xlsx-sheet2.csv"

xlsx_python_ok=0
if command -v python3 >/dev/null 2>&1; then
  if python3 -c "import openpyxl" >/dev/null 2>&1; then
    xlsx_python_ok=1
  fi
fi

if [ "$xlsx_python_ok" -eq 0 ]; then
  echo "SKIP: xlsx (python3 or openpyxl absent)"
  skip=$((skip + 1))
elif [ ! -f "$XLSX_ADAPTER" ]; then
  echo "FAIL: xlsx adapter-missing ($XLSX_ADAPTER)"
  fail=$((fail + 1))
elif [ ! -f "$XLSX_FIXTURE" ]; then
  echo "FAIL: xlsx fixture-missing ($XLSX_FIXTURE)"
  fail=$((fail + 1))
elif [ ! -f "$XLSX_EXPECTED1" ]; then
  echo "FAIL: xlsx expected-sheet1-missing ($XLSX_EXPECTED1)"
  fail=$((fail + 1))
elif [ ! -f "$XLSX_EXPECTED2" ]; then
  echo "FAIL: xlsx expected-sheet2-missing ($XLSX_EXPECTED2)"
  fail=$((fail + 1))
else
  XLSX_OUTDIR="$(mktemp -d "${TMPDIR:-/tmp}/m036-sc9-xlsx.XXXXXX")"
  set +e
  bash "$XLSX_ADAPTER" "$XLSX_FIXTURE" --out-dir "$XLSX_OUTDIR" >/dev/null 2>&1
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    echo "FAIL: xlsx exit-0 (rc=$rc)"
    fail=$((fail + 1))
  else
    sheet1_ok=0
    sheet2_ok=0
    if [ -f "$XLSX_OUTDIR/Sheet1.csv" ]; then
      if diff -q "$XLSX_OUTDIR/Sheet1.csv" "$XLSX_EXPECTED1" >/dev/null 2>&1; then
        sheet1_ok=1
      fi
    fi
    if [ -f "$XLSX_OUTDIR/Sheet2.csv" ]; then
      if diff -q "$XLSX_OUTDIR/Sheet2.csv" "$XLSX_EXPECTED2" >/dev/null 2>&1; then
        sheet2_ok=1
      fi
    fi
    if [ "$sheet1_ok" -eq 1 ] && [ "$sheet2_ok" -eq 1 ]; then
      echo "PASS: xlsx per-sheet-CSVs-byte-identical"
      pass=$((pass + 1))
    else
      echo "FAIL: xlsx per-sheet-CSVs (sheet1_ok=$sheet1_ok sheet2_ok=$sheet2_ok)"
      fail=$((fail + 1))
    fi
  fi
  rm -rf "$XLSX_OUTDIR"
fi

# --- summary --------------------------------------------------------------
echo "BATTERY: pass=$pass fail=$fail skip=$skip"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
