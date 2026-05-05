# DECISIONS — Imaginary Notes App

A lightweight register of architecture decisions that anchor the MVP
build. Each decision carries a stable identifier so upstream documents
can cite it.

## DR-001 Pick framework

Title: Pick framework.
Rationale: We pick a single full-stack framework that supports both
edge runtime and traditional Node deploys, so the deploy decision can
defer without forcing a rewrite.
Status: Accepted.

## DR-002 Deploy via Vercel

Title: Deploy via Vercel.
Rationale: Vercel gives us the fastest path from commit to production
URL, with preview deploys per pull request. The team's existing
muscle memory is on Vercel, and switching to a different host would
add weeks to the MVP timeline.
Status: Accepted.

## DR-003 Database choice

Title: Database choice.
Rationale: We choose a managed Postgres provider over a self-hosted
option to avoid operational burden during the MVP. The provider
supports point-in-time recovery and per-branch databases.
Status: Accepted.
