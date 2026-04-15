#!/usr/bin/env bash
set -eu
test ! -d .specify/scripts/bash || { echo "FAIL: .specify/scripts/bash still exists"; exit 1; }
echo "PASS: .specify/scripts/bash is absent"
