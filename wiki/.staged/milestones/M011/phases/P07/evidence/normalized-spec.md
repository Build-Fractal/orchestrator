<!-- source_hash: 144a7519ea1ae10c52eb801ef1161a627d7070a0b504375e04eec3460bdfed4d -->
# Feature Specification: Inventory Reconciliation

## Problem Statement

Warehouse operators spend the first half of every shift reconciling inventory
counts by hand across three independent systems: the warehouse management
system (WMS), the accounting ledger, and the supplier's EDI receipts feed.
The three systems disagree on sku normalization, operators must mentally
translate between them, and mistakes are common.

## User Scenarios & Testing

### User Story 1 - Reconcile three sources daily (Priority: P1)

**As a** warehouse operator **I want** a daily three-way reconciliation report
**So that** I can triage discrepancies by category instead of scanning
spreadsheets line by line.

### User Story 2 - Drill down into flagged lines (Priority: P1)

**As a** warehouse operator **I want** a per-line drill-down showing WMS,
ledger, and EDI values side-by-side **So that** I can understand the root
cause of a flag without running manual spot-checks.

### User Story 3 - Propose sku-normalization rules (Priority: P2)

**As a** veteran operator **I want** to propose changes to the sku
normalization rules via versioned configuration **So that** my tribal
knowledge is captured without a code deploy.

### User Story 4 - Tolerate late EDI feeds (Priority: P2)

**As a** warehouse operator **I want** the reconciliation service to
tolerate late or missing EDI feeds **So that** a late supplier does not
produce a noisy "every line is missing" report.

## Functional Requirements

- **FR-001**: The service MUST ingest WMS, ledger, and EDI feeds on a fixed
  daily schedule.
- **FR-002**: The service MUST normalize sku identifiers into a canonical
  form before any pairwise diff.
- **FR-003**: The reconciliation report MUST group discrepancies by root
  cause (sku-mapping, quantity-delta, missing-in-source).
- **FR-004**: The drill-down view MUST display WMS, ledger, and EDI values
  for each flagged line alongside a plain-language explanation.
- **FR-005**: The sku-normalization rules MUST be exposed as versioned
  configuration editable without a code deploy.
- **FR-006**: The service MUST tolerate a late or missing EDI feed without
  producing a flood of missing-in-source flags.

## Acceptance Scenarios

1. **Given** all three daily feeds are present, **When** the reconciliation
   service runs, **Then** a categorized report of discrepancies is emitted
   within the operator's morning shift window.
2. **Given** a flagged line item, **When** the operator drills in, **Then**
   all three source values are shown side-by-side with a plain-language
   explanation of why the line was flagged.
3. **Given** the EDI feed has not arrived by the scheduled reconciliation
   time, **When** the service runs, **Then** the report flags the EDI feed
   as late and suppresses the per-line missing-in-EDI flags.

## Constraints

- Daily batch cadence is sufficient; real-time reconciliation is not a goal.
- The service must never write back to WMS, ledger, or EDI source systems.

## Non-Goals

- Real-time (sub-hour) reconciliation.
- Automatic correction of discrepancies in source systems.
- Integration with supplier portals for disputing EDI errors.
