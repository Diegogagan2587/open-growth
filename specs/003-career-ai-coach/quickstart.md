# Quickstart Validation: Career AI Coach

## Prerequisites

From the repository root:

```bash
bin/rails db:test:prepare
```

Use an account with AI enabled for the system, account, and membership. Use the existing test fixtures and create career records only where the scenario needs unique state.

## Focused automated validation

```bash
bin/rails test test/models/reporting/conversation_test.rb test/services/reporting/analysis_snapshot_test.rb test/services/reporting/answer_question_test.rb test/controllers/reports/ai/conversations_controller_test.rb
```

The implementation should add focused tests for the career domain object/snapshot, domain-aware prompt selection, career conversation creation, and shared chat rendering. Snapshot and conversation rules should be tested at model/domain-object boundaries; the existing provider boundary should be tested only for delegation and external failure behavior.

## Manual end-to-end scenarios

1. Open the career dashboard and start career analysis in the existing shared AI chat. Confirm the conversation is labeled career, uses an account-scoped date range, and shows career guidance in the empty state.
2. With applications across `applied`, `screening`, `interviewing`, and `rejected`, ask for analysis. Confirm the first response includes funnel snapshot, bottleneck, evidence, recommendations, limitations, and next steps.
3. Ask a follow-up question. Confirm it uses the same career context without requiring re-entry of the records.
4. Add another account’s application and verify it is absent from the generated career snapshot and response.
5. Request analysis with no or sparse applications. Confirm the response explains unavailable metrics and does not invent rates or hiring probabilities.
6. Select optional profile/notes/tasks/meetings context explicitly and verify only selected, authorized records are included.
7. Disable AI access or exhaust the quota. Confirm the existing actionable error appears and career records remain unchanged.
8. Open a financial conversation after a career conversation. Confirm the shared chat preserves each conversation’s domain and does not mix records.

## Quality checks

```bash
bin/rails test
bin/rubocop
bin/brakeman --no-pager
```

Run Herb linting for modified ERB views if configured by the repository. Verify keyboard navigation, labels, readable status/error text, and responsive layout for the shared chat and career entry points.
