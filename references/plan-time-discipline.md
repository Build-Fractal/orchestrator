# Plan-Time Discipline — Reference

**Audience**: Anyone authoring a phase plan or a task plan, anyone
operating `orchestrator:plan-phase`, anyone reviewing a plan before
dispatch.

**Captured**: 2026-05-11 (Path 1 ratification of the Tier 2 XXII + XII
inheritance amendment; Change 6 deliverable lifts the Deep Modules
vocabulary into `references/`).

The mechanical fail-fast rules that govern plan-authoring time live in
[`commands/plan-phase.md`](../commands/plan-phase.md) under § Plan-Time
Discipline (Verification + Prerequisites) — those are the six numbered
checks every plan author MUST satisfy. This reference doc captures
**planning lenses**: vocabularies and discipline frames that don't
fail mechanically but make plans better when applied.

---

## Deep Modules — a planning lens

**Source**: `mattpocock/skills::improve-codebase-architecture` (MIT).
Formalizes a vocabulary the orchestrator's planning prose has been
working around without naming.

### Vocabulary

- **Module** — any unit with an interface and an implementation
  (function, class, package, slice).
- **Interface** — everything callers must know: types, invariants,
  error modes, ordering, config.
- **Implementation** — the code inside.
- **Depth** — leverage at the interface. *Deep* modules expose simple
  interfaces over complex implementations; *shallow* modules expose
  interfaces whose complexity mirrors implementation complexity
  (callers gain nothing).
- **Seam** — where an interface lives; the place behavior alters
  without in-place editing.
- **Adapter** — a concrete implementation satisfying an interface at
  a seam.
- **Locality** — what maintainers gain when one concern concentrates
  in one place.

### Operative principle

**The interface is the test surface.**

If a module's interface is the contract callers depend on, then the
interface is also the surface against which tests must verify
behavior. Tests against implementation internals couple to the wrong
thing and rot when the implementation is restructured.

### The deletion test

When evaluating an existing module — or a proposed module in a plan —
ask: *would removing this module concentrate complexity, or just
relocate it?*

A deep module passes: removing it would either concentrate complexity
elsewhere (eroding locality) or force every caller to re-implement
the simple-interface-over-complex-internals contract the module
provided.

A shallow module fails: removing it just relocates the same handful
of lines to the call site, with no loss of leverage. Shallow modules
are pure overhead — they consume context budget (Principle I) and
maintenance surface without paying for either.

### Orchestrator-specific notes

1. **Adapters at runtime seams.** The orchestrator's existing adapter
   pattern *is* this pattern, by example:
   - `scripts/dispatch/adapters/backend/<runtime>.sh` — dispatch-
     backend adapter seam.
   - `scripts/runtime/<runtime>/` — per-runtime helpers.
   - The format-tier adapter tree under `scripts/knowledge/lib/`
     (Tier 0 / Tier 1 / Tier 2 extraction adapters).

   Naming the pattern aligns prose so future plans (M009 multi-
   runtime parity, M010 Managed Agents + Codex Cloud) inherit the
   vocabulary without re-deriving it.

2. **Deletion test as planning gate (optional).** When
   `orchestrator:plan-phase` proposes a new helper script or new
   `references/` doc, the planner SHOULD apply the deletion test in
   the plan's *Risk* section. Not a hard gate; a discipline.
   Composes with Constitution Principle III (Design Before Code)
   and Principle XIV (No Speculative Complexity).

   The deletion test surfaces shallow-module proposals before they
   land — the planner records, in plan prose: "Removing this helper
   would relocate N lines into K call sites; depth = (K, complexity
   delta). If K ≤ 2 and the complexity delta is small, prefer
   inlining."

3. **Interface as the test surface — orchestrator example.** The
   knowledge graph (`KNOWLEDGE.md` + `KNOWLEDGE-INDEX.md`) exposes a
   simple lookup-by-tag interface over a complex hierarchical
   storage implementation (hot/warm/cold tiers). Tests verify the
   lookup interface, not the storage internals. When M020 / M037
   reshaped the cold-tier storage, the lookup-interface tests held
   without modification — confirming the depth.

### Why this lens is not a constitutional principle

The Deep Modules vocabulary is a **planning lens**, not a falsifiable
rule about orchestrator behavior. It guides judgment at design time;
it does not flag a mechanical violator that a CI check could detect.

Per the Inclusion Criteria gate (build-fractal Tier 1 inheritance,
Governance § "Inclusion Criteria for New Principles"), a candidate
that fails the *mechanical verification capability* test is routed
to operational guidance — exactly what this reference doc is.

---

## Cross-references

- `commands/plan-phase.md` § Plan-Time Discipline (Verification +
  Prerequisites) — the six mechanical rules every plan author MUST
  satisfy.
- `commands/plan-phase.md` § Risk (template) — where the deletion
  test, when applied, lands as plan prose.
- `.orchestrator/memory/constitution.md` § Principle III (Design
  Before Code), § Principle XIV (No Speculative Complexity), §
  Principle XV (Surgical Precision) — the constitutional principles
  this lens composes with.
- `references/architecture.md` — orchestrator architecture overview;
  the adapter seams named above are documented there.
