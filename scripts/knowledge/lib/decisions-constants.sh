#!/usr/bin/env bash
# scripts/knowledge/lib/decisions-constants.sh — M034 P01 (CON-4 SSOT).
#
# Single source of truth for every decision-packet enum, default, and
# threshold. Sourced by write-decisions.sh, read-decisions.sh,
# decisions-from-conversus.sh, check-decisions.sh, and the M034 P01
# verifiers. No top-level execution — defines variables + helper
# validators only. Bash 3.2 / POSIX-sh (CON-1 / AD-19).
#
# FR-1: "Any weight/threshold/severity boundary appears as a NAMED
# CONSTANT in exactly one place that prompts/docs/tests reference."
# This file IS that place. Do not redeclare these values anywhere else.

# Schema version stamped into every emitted *-DECISIONS.md frontmatter.
DECISIONS_SCHEMA_VERSION="1.0"

# severity in {warn, block}; default block (FR-1).
DECISIONS_SEVERITY_VALUES="warn block"
DECISIONS_SEVERITY_DEFAULT="block"

# type in {decision, boundary_translation}; default decision (FR-1).
DECISIONS_TYPE_VALUES="decision boundary_translation"
DECISIONS_TYPE_DEFAULT="decision"

# FR-4: when the count of active, unreviewed, warn-severity decision
# entries reaches this threshold, `doctor` raises an advisory health
# finding ("recurring unreviewed warn-severity entries"). v1 semantics
# are count-based (not time-series); see M034-P01-ADDENDUM.md.
DECISIONS_WARN_FINDING_THRESHOLD="3"

# Validator: print "ok" if $1 is a member of the severity enum, else "".
decisions_is_valid_severity() {
  case " $DECISIONS_SEVERITY_VALUES " in
    *" $1 "*) printf 'ok' ;;
    *) printf '' ;;
  esac
}

# Validator: print "ok" if $1 is a member of the type enum, else "".
decisions_is_valid_type() {
  case " $DECISIONS_TYPE_VALUES " in
    *" $1 "*) printf 'ok' ;;
    *) printf '' ;;
  esac
}
