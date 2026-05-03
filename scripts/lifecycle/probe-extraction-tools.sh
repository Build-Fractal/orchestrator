#!/usr/bin/env bash
# scripts/lifecycle/probe-extraction-tools.sh -- M036 P01 host-tool probe.
#
# Reports presence of the three external tools the M036 Tier 1 format
# adapters depend on. Informational ONLY -- exits 0 regardless of
# presence. Do NOT use this as a gate; the adapters themselves report
# missing-tool errors at extract time.
#
# Probed tools (canonical adapter list at
# scripts/dispatch/adapters/format/registry.tsv):
#
#   pdftotext   -- pdf adapter (poppler-utils)
#   pandoc      -- docx adapter (pandoc)
#   openpyxl    -- xlsx adapter (Python openpyxl module)
#
# Output shape (one line per tool, fixed order; hint follows when missing;
# trailing SUMMARY line always emitted):
#
#   pdftotext: present=<yes|no> path=<path-or-empty>
#     hint: brew install poppler                   (only when missing)
#   pandoc: present=<yes|no> path=<path-or-empty>
#     hint: brew install pandoc                    (only when missing)
#   openpyxl: present=<yes|no> python=<path-or-empty>
#     hint: pipx install openpyxl  # or: python3 -m pip install --user openpyxl   (only when missing)
#   SUMMARY: probe pdftotext=<y|n> pandoc=<y|n> openpyxl=<y|n>
#
# Bash 3.2 / POSIX-sh per CON-2. No declare -A. No jq dependency.
set -u

# pdftotext
pdftotext_path=""
pdftotext_yn="n"
if command -v pdftotext >/dev/null 2>&1; then
  pdftotext_path="$(command -v pdftotext)"
  pdftotext_yn="y"
  echo "pdftotext: present=yes path=${pdftotext_path}"
else
  echo "pdftotext: present=no path="
  echo "  hint: brew install poppler"
fi

# pandoc
pandoc_path=""
pandoc_yn="n"
if command -v pandoc >/dev/null 2>&1; then
  pandoc_path="$(command -v pandoc)"
  pandoc_yn="y"
  echo "pandoc: present=yes path=${pandoc_path}"
else
  echo "pandoc: present=no path="
  echo "  hint: brew install pandoc"
fi

# openpyxl (probed via python3 -c)
python3_path=""
openpyxl_yn="n"
if command -v python3 >/dev/null 2>&1; then
  python3_path="$(command -v python3)"
fi
if [ -n "${python3_path}" ] && python3 -c "import openpyxl" >/dev/null 2>&1; then
  openpyxl_yn="y"
  echo "openpyxl: present=yes python=${python3_path}"
else
  echo "openpyxl: present=no python=${python3_path}"
  echo "  hint: pipx install openpyxl  # or: python3 -m pip install --user openpyxl"
fi

echo "SUMMARY: probe pdftotext=${pdftotext_yn} pandoc=${pandoc_yn} openpyxl=${openpyxl_yn}"
exit 0
