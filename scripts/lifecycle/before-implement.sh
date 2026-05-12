#!/usr/bin/env bash
# scripts/lifecycle/before-implement.sh -- Orchestrator pre-implement hook.
#
# M008/P06/T02 enrolled the before-implement lifecycle event in
# packaging/bundle/hooks/before-implement.json with command
# "bash scripts/lifecycle/before-implement.sh", described in the T02 plan
# as a placeholder that "the installer in T03 wires up through the
# runtime adapter's --hook-config path rather than executing directly."
# The on-disk script was deferred at M008 time and never authored, so
# the hook command fail-silently 404'd whenever the runtime fired it.
# This is the matching shim, modeled on before-commit.sh (M028) shape.
#
# Permissive no-op: returns 0 unconditionally so the underlying
# implementation dispatch proceeds. Future enrichment (pre-implement
# plan-shape validation, dependency probe) can extend this body in
# place; the shim exists so the bundle's extension-point contract has
# a real on-disk source to stage.
#
# Bash 3.2 compatible. No assoc-arrays, no array-from-stdin builtins.
# AD-19 single-script-file flat shape. AP-009 clean.

set -u

exit 0
