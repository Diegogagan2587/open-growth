# Shared AI Chat Contract

## Conversation creation

The existing `POST /reports/ai/conversations` resource accepts the existing title/date fields plus:

- `analysis_domain`: `financial` or `career`; default remains `financial` for backward compatibility.
- `career_context`: optional, explicitly selected career context flags; ignored or rejected for financial conversations.

The authenticated membership must belong to the current account and have AI access. Invalid domain/context or invalid date range returns the existing form error flow and creates no conversation.

Career entry points from the career dashboard or application context create the same reporting conversation resource with `analysis_domain=career` and an appropriate date range/title.

## Turn creation

The existing `POST /reports/ai/conversations/:conversation_id/turns` resource remains the turn boundary. Authorization is performed through the current account membership’s conversation relation. The existing quota, rate-limit, queued/processing/failed states, and actionable error behavior remain in force.

Each turn must use the conversation’s persisted domain and context selection. A career turn receives only the account-scoped career snapshot; a financial turn receives only the financial snapshot. The provider must not receive unauthorized records or raw secrets.

## Successful response behavior

The first career response contains these recognizable sections:

1. Funnel snapshot
2. Bottleneck findings
3. Supporting evidence
4. Recommendations
5. Limitations
6. Next steps

Follow-up responses remain conversational, use the same context, distinguish facts from user-provided context/hypotheses/recommendations, and remain read-only.

## UI contract

The shared chat visibly identifies the analysis domain and scope, uses career-specific empty-state guidance for career conversations, exposes a keyboard-accessible question form, and presents loading/failure states through existing turn rendering. Career links must preserve account/session authorization and should return users to the shared conversation view.

## Safety and isolation

- A user cannot load another membership’s conversation.
- Career snapshot queries are scoped to `Current.account` and the conversation’s immutable range.
- Recommendations do not create/update applications, events, tasks, meetings, documents, or profiles.
- Provider failure, rate limit, disabled access, or invalid output does not mutate career data.
