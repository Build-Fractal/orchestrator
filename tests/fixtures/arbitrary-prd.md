# Product: Inventory Reconciliation

## Problem

Warehouse operators currently reconcile daily inventory counts by hand against
three independent systems: the warehouse management system (WMS), the accounting
ledger, and the supplier's EDI receipts feed. Each pairwise comparison takes
about ninety minutes, and a full three-way reconciliation consumes the first
half of every operator's shift. Mistakes are common because the three systems
disagree on sku normalization rules, and the human operator has to mentally
translate between them while scanning through spreadsheets.

The team has tried building one-off scripts to diff any two systems, but none
of those scripts are trusted enough to be the single source of truth. When a
discrepancy surfaces, operators still fall back to manual spot-checks because
no tool can explain why it flagged a particular line item.

The organization has around forty warehouses, each running this ritual every
morning. The cumulative cost is roughly sixty operator-hours per day, and the
resulting reconciliation artifact is still a spreadsheet that nobody outside
the operator's immediate team can read.

## Proposal

- Build a reconciliation service that ingests the three source feeds on a fixed
  schedule and normalizes sku identifiers into a single canonical form before
  any diffing happens.
- Emit a daily reconciliation report that lists discrepancies grouped by root
  cause (sku-mapping, quantity-delta, missing-in-source) rather than by raw
  spreadsheet row, so operators can triage by category instead of line-by-line.
- Provide a drill-down view for each flagged line item that shows the exact
  values from all three sources alongside a plain-language explanation of why
  the line was flagged.
- Expose the canonical sku-normalization rules as versioned configuration that
  operators can propose changes to without shipping new code.

## Risks

The sku-normalization rules are the hardest part. Different suppliers encode
variant information (color, pack size, lot) in different positions of the sku
string, and some rules are undocumented tribal knowledge held by veteran
operators. If the normalization layer gets even a handful of rules wrong, the
reconciliation output will be noisier than the manual process it replaces, and
operators will lose trust in the tool within the first week.

The EDI feed is notoriously late — it arrives anywhere from 2 AM to 9 AM
depending on the supplier. The reconciliation service has to tolerate late or
missing feeds without producing a noisy "every line item is missing" report.

## Out of Scope

- Real-time (sub-hour) reconciliation. Daily batch is sufficient for the
  operator workflow and keeps the data volume tractable.
- Automatic correction of discrepancies in source systems. The service reports
  discrepancies but never writes back to WMS, the ledger, or EDI.
- Integration with supplier portals for disputing EDI errors. That is a manual
  workflow today and is out of scope for this initial build.
