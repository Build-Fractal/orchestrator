#!/usr/bin/env bash
# M035 P05 T05 — fixture install.sh for shape verification.
# NOT a real installer; produces a deterministic byte-stream that
# the SHA256SUMS file references. Real install.sh is shipped by
# P04 (curl-pipe-bash) and signed at release time by
# .github/workflows/release.yml (T03).
echo "FIXTURE: m035-p05 release-fixture install.sh"
echo "If you ran this expecting a real install, something is wrong."
exit 1
