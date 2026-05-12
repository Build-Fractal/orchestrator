#!/usr/bin/env bash
# scripts/lifecycle/after-implement.sh -- Orchestrator post-implement hook.
#
# M008/P06/T02 enrolled the after-implement lifecycle event in
# packaging/bundle/hooks/after-implement.json with command
# "bash scripts/lifecycle/after-implement.sh", described in the T02 plan
# as a placeholder that "the installer in T03 wires up through the
# runtime adapter's --hook-config path rather than executing directly."
# The on-disk script was deferred at M008 time and never authored, so
# the hook command fail-silently 404'd whenever the runtime fired it.
# This is the matching shim, modeled on before-commit.sh (M028) shape.
#
# Permissive no-op: returns 0 unconditionally so the underlying
# post-implement path proceeds. Future enrichment (phase transition
# gate, rollback decision) can extend this body in place; the shim
# exists so the bundle's extension-point contract has a real on-disk
# source to stage.
#
# Bash 3.2 compatible. No assoc-arrays, no array-from-stdin builtins.
# AD-19 single-script-file flat shape. AP-009 clean.

set -u

exit 0
