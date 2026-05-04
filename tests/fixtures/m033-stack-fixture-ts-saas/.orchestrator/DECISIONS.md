# Decisions

## DR-DEMO-001: Use Next.js App Router

We adopt Next.js App Router as the routing/runtime model for the SaaS
surface. App Router gives us nested layouts, streaming, and server
components by default, which matches our SaaS dashboard pattern.

## DR-DEMO-002: Co-locate tests with source

Tests live under `tests/` mirroring the `src/` tree. Co-location keeps
the test-to-source jump short and avoids a parallel directory tree
for spec files.
