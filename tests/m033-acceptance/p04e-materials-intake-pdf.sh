#!/usr/bin/env bash
# Defect 4 regression: PDFs were probed for converter availability but
# never actually converted. The PDF path was appended verbatim to the
# materials list and extract_token_refs grep'd the binary, surfacing
# phantom orphan-reference conflicts from binary byte sequences.
#
# Asserts: a token-free PDF produces zero PDF-derived conflicts. The PDF
# is either skipped (no pdftotext, with stderr diagnostic) or converted
# to a sidecar .txt — never grep'd verbatim.

set -e
set -u

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf 'FAIL: %s\n' "$1"; }
skip() { SKIP_COUNT=$((SKIP_COUNT + 1)); printf 'SKIP: %s\n' "$1"; }

REPO_ROOT="$(pwd)"

# Build a tiny PDF on the fly. Body contains zero `[A-Z]+-[0-9]+` ASCII
# tokens — anything matching that pattern in refs-all.txt would have to
# come from binary-grep contamination.
write_token_free_pdf() {
    local out="$1"
    printf '%%PDF-1.4\n%%\xe2\xe3\xcf\xd3\n' > "$out"
    cat >>"$out" <<'EOF'
1 0 obj
<< /Type /Catalog /Pages 2 0 R >>
endobj
2 0 obj
<< /Type /Pages /Kids [3 0 R] /Count 1 >>
endobj
3 0 obj
<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>
endobj
4 0 obj
<< /Length 44 >>
stream
BT /F1 12 Tf 100 700 Td (just plain prose) Tj ET
endstream
endobj
xref
0 5
0000000000 65535 f
0000000018 00000 n
0000000063 00000 n
0000000110 00000 n
0000000183 00000 n
trailer
<< /Size 5 /Root 1 0 R >>
startxref
260
%%EOF
EOF
}

run_pdf_no_phantom_test() {
    local stage
    stage="$(mktemp -d)"

    # Sibling .md primary so labeling has something to bind to.
    cat >"$stage/PRIMARY-BRIEF.md" <<'EOF'
# Primary
Plain prose. No token references here.
EOF
    write_token_free_pdf "$stage/SUPPLEMENTARY.pdf"

    local out="$stage/intake-stdout.txt"
    M033_INTAKE_TIMESTAMP=20260504T000000Z bash scripts/lifecycle/materials-intake.sh \
        --project-dir "$stage" --yes >"$out" 2>&1 || true

    local intake_dir="$stage/.orchestrator/intake/20260504T000000Z"
    local conflicts="$intake_dir/conflicts-acc.txt"

    # Pre-fix symptom: PDF base appears in conflicts-acc.txt because the
    # binary was grep'd verbatim. Post-fix: never.
    if [ -f "$conflicts" ]; then
        if grep -qF 'SUPPLEMENTARY.pdf' "$conflicts"; then
            fail "PDF binary path appears in conflicts-acc.txt — binary-grep contamination"
        else
            pass "PDF binary path does not appear in conflicts-acc.txt"
        fi
    else
        pass "conflicts-acc.txt absent (zero conflicts as expected for token-free input)"
    fi

    # Materials list should either omit the PDF (skipped) OR list a
    # sidecar .txt under _originals/ (converted). The verbatim binary
    # path must NOT appear in materials.txt.
    local mats="$intake_dir/materials.txt"
    if [ -f "$mats" ] && grep -q '\.pdf$' "$mats"; then
        fail "materials.txt contains a .pdf path verbatim — should be sidecar or skipped"
    else
        pass "materials.txt does not contain any verbatim .pdf path"
    fi

    rm -rf "$stage"
}

run_pdf_no_phantom_test

printf 'SUMMARY: p04e-materials-intake-pdf.sh pass=%d fail=%d skip=%d\n' "$PASS_COUNT" "$FAIL_COUNT" "$SKIP_COUNT"
if [ "$FAIL_COUNT" -ne 0 ]; then
    exit 1
fi
exit 0
