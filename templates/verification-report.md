---
schema_version: "1.0"
type: verification-report
milestone: "{{milestone_id}}"
phase: "{{phase_id}}"
overall_result: "{{overall_result}}"
verified_at: "{{verified_at}}"
---

## Tier 1: Static Checks

- **Status**: {{tier1_status}}
- **Checks**: {{tier1_checks}}
- **Failures**: {{tier1_failures}}

| # | Check | Expected | Actual | Result |
|---|-------|----------|--------|--------|
| {{tier1_row_num}} | {{tier1_check_name}} | {{tier1_expected}} | {{tier1_actual}} | {{tier1_result}} |

## Tier 2: Command Execution

- **Status**: {{tier2_status}}
- **Checks**: {{tier2_checks}}
- **Failures**: {{tier2_failures}}

| # | Command | Exit Code | Output | Result |
|---|---------|-----------|--------|--------|
| {{tier2_row_num}} | {{tier2_command}} | {{tier2_exit_code}} | {{tier2_output}} | {{tier2_result}} |

## Tier 3: Behavioral Verification

- **Status**: {{tier3_status}}
- **Checks**: {{tier3_checks}}
- **Failures**: {{tier3_failures}}

| # | Behavior | Observation | Result |
|---|----------|-------------|--------|
| {{tier3_row_num}} | {{tier3_behavior}} | {{tier3_observation}} | {{tier3_result}} |

## Tier 4: Human/UAT Review

- **Status**: {{tier4_status}}
- **Checks**: {{tier4_checks}}
- **Failures**: {{tier4_failures}}

| # | Review Item | Reviewer | Notes | Result |
|---|-------------|----------|-------|--------|
| {{tier4_row_num}} | {{tier4_item}} | {{tier4_reviewer}} | {{tier4_notes}} | {{tier4_result}} |
