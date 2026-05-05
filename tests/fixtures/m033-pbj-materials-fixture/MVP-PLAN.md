# MVP-PLAN — Imaginary Notes App

## Goals

The MVP must demonstrate that capture and recall work as a single
seamless flow across at least two device classes (desktop and mobile
web). Anything beyond capture-and-recall is explicitly out of scope
for this iteration.

The goal is to ship a vertical slice that proves the core loop, not
to ship every feature on the long-term roadmap.

## User Stories

- US-1: Capture a note from any device. Acceptance: a note typed on
  desktop is persisted within 500ms and is retrievable via the search
  endpoint on the same device.
- US-2: Search across all captured notes. Acceptance: a substring
  query returns matching notes in under 200ms for a 1000-note corpus.

These two user stories form the entirety of the MVP scope. No other
US- identifiers are defined at this layer.

## Deployment Target

The MVP deploys to Cloudflare Workers as the production runtime. This
gives us global edge presence with no per-region orchestration burden.

## Timeline

MVP timeline: 6 weeks.

## Risks

The Cloudflare Workers cold-start envelope has not been measured for
our framework choice; we may discover at integration time that the
recall latency budget cannot be met under cold-start conditions. A
fallback to a long-running region would extend the timeline.
