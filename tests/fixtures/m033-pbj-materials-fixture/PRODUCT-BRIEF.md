# PRODUCT-BRIEF — Imaginary Notes App

## Problem

End users juggle scattered note-taking tools that fragment their daily
context. Notes live in three places, none of which talk to each other,
and recall across devices is unreliable enough that users give up and
re-type the same content from memory more than once a week.

## Target User

Knowledge workers who already keep notes across multiple tools and
have given up on a unified workflow because none of the existing
options handle their cross-device reality.

## Scope

The MVP covers three user stories:

- US-1: capture a note from any device.
- US-2: search across all captured notes.
- US-3: synchronise notes across devices in near-real-time.

US-3 is in-scope for the MVP because the synchronisation gap is the
root cause of the abandonment pattern observed in the problem
statement.

## Architecture Decisions

The architecture is anchored by two architecture decisions documented
in DECISIONS.md: DR-001 (framework choice) and DR-002 (deployment
target). These two together fix the deploy story.

## Timeline

MVP timeline: 4 weeks.
