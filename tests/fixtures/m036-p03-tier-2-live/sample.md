# Synthetic Long-Term-Care Staffing Calculation Rule

> **Smoke-test fixture only.** Authored for the M036 P03 live-LLM extraction
> smoke test. Mimics the shape of a CMS-style PBJ regulatory document
> (definitions → calculations → exclusions → edge cases) but contains no
> real regulatory content. Numbers and thresholds are illustrative.

## 1. Scope

This rule defines how nursing-staff hours and resident census are combined
to produce the hours-per-resident-day (HPRD) metric for a measurement
window. It applies to all skilled-nursing facilities subject to staffing
disclosure under section 7401 of the Synthetic Care Compliance Act of 2025.

## 2. Definitions

### 2.1 Resident Census

The **resident census** is the count of residents physically present in
the facility at the measurement instant. The default measurement instant
is 23:59:00 local time on each day of the measurement window. Residents
on temporary leave (hospital transfer, home leave) are excluded if the
absence exceeds 24 hours.

### 2.2 Direct-Care Nursing Staff

**Direct-care nursing staff** comprises:

- Registered nurses (RNs) providing bedside care
- Licensed practical nurses (LPNs)
- Certified nursing assistants (CNAs)
- Medication aides (where state-licensed)

The following are **excluded** from direct-care staff:

- Administrative nursing roles (Director of Nursing, Assistant DON)
- Training-only hours (orientation, in-service)
- Contracted agency staff whose hours are reported under a separate sidecar

### 2.3 Measurement Window

A **measurement window** is a calendar quarter (Q1: Jan–Mar, Q2: Apr–Jun,
etc.) unless the facility has applied for and received a non-standard
window per section 7401(c)(3).

## 3. Calculation

### 3.1 Hours-Per-Resident-Day (HPRD)

For each day `d` in the measurement window:

```
HPRD(d) = staff_hours(d) / resident_census(d)
```

The reported metric is the unweighted arithmetic mean of `HPRD(d)` across
all days in the window where `resident_census(d) > 0`. Days with zero
census are excluded from the denominator.

### 3.2 Rounding

All HPRD values are rounded to two decimal places using banker's rounding
(round-half-to-even). Intermediate values used in supersection 3.4
weighting calculations are not rounded until final reporting.

### 3.3 RN-Specific HPRD

The RN-specific HPRD uses the same denominator (resident census) but a
restricted numerator (RN hours only). This metric must be reported
alongside the aggregate HPRD when the facility has filed under
disclosure category 7401(b).

### 3.4 Weighted Aggregate

The weighted aggregate HPRD across multiple facilities owned by a single
operator is computed as:

```
HPRD_agg = sum(staff_hours_f * weight_f) / sum(census_f * weight_f)
```

where `weight_f` is the bed-licensed capacity of facility `f` divided by
the total bed-licensed capacity of the operator portfolio.

## 4. Exclusions and Edge Cases

### 4.1 Closed Measurement Days

Days on which the facility was closed to admissions due to a
state-declared emergency are excluded from both numerator and denominator.
The exclusion must be documented in the facility's operating log with a
reference to the state declaration.

### 4.2 Census-Zero Days

If `resident_census(d) = 0` for any day in the measurement window, that
day is dropped from the HPRD calculation as defined in section 3.1. The
day is **not** treated as a missing-data day.

### 4.3 Partial-Day Admissions

A resident admitted at any point on day `d` is counted in
`resident_census(d)` regardless of admission time. A resident discharged
on day `d` is counted in `resident_census(d)` only if discharge occurred
after the measurement instant.

### 4.4 Hospice Residents

Residents under the facility's hospice program are counted in resident
census. Hospice-only staff (chaplains, social workers) are not counted
in direct-care nursing staff hours.

## 5. Reporting

Facilities must submit HPRD figures via the Synthetic Care Disclosure
Portal within 45 calendar days of the measurement window's close.
Late submissions are subject to disclosure-noncompliance penalties as
defined in section 7401(e).

## 6. Effective Date

This rule is effective for measurement windows beginning on or after
2026-01-01. Measurement windows beginning before that date follow the
prior rule under section 7401 (revision 2024-03).
