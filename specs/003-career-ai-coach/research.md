# Research: Career AI Coach

## Decision: Extend `Reporting::Conversation`

- **Decision**: Add a domain/context concept to the existing reporting conversation rather than creating a career chat model.
- **Rationale**: The current chat already owns turns, quotas, usage history, authorization through account membership, background execution, Turbo updates, and retention behavior. The clarified requirement explicitly calls for one shared chat experience.
- **Alternatives considered**: A separate `Career::Conversation` would duplicate access control, usage accounting, job execution, rendering, and follow-up behavior; it would also contradict the shared-chat requirement.

## Decision: Use model-owned domain objects as provider boundaries

- **Decision**: Keep financial and career snapshot behavior as explicit domain objects under `app/models/reporting`, selected through `Reporting::Conversation` domain APIs. Move/re-home existing snapshot business behavior from the legacy service location as part of implementation if needed.
- **Rationale**: Snapshot serialization is domain behavior and the provider boundary that limits data sent externally. Separate snapshot builders keep financial and career schemas explicit and make account isolation testable while following the project’s Rails-native domain-model constitution.
- **Alternatives considered**: Adding another object under `app/services` would continue the deprecated business-logic placement; a single untyped aggregate snapshot risks sending unrelated records and mixing financial and career instructions.

## Decision: Store explicit domain and optional context selection

- **Decision**: Persist a canonical domain such as `financial` or `career`, plus a small explicit selection for optional career context and the date range on the conversation.
- **Rationale**: Follow-up turns must preserve the original scope without asking the user to restate it. Persisted selection also prevents a later request from silently changing the analysis context.
- **Alternatives considered**: Inferring domain from each question would make follow-ups ambiguous; storing only free-form prompt text would not provide a reliable authorization or reproducibility boundary.

## Decision: Keep provider orchestration thin

- **Decision**: Keep `Reporting::AnswerQuestion`, `Reporting::AnswerQuestionJob`, usage events, quotas, and failure states as the existing provider/application boundary, but make it delegate snapshot and instruction selection to model/domain APIs.
- **Rationale**: This preserves existing operational behavior and avoids a second provider integration without allowing the provider adapter to become the owner of career or financial business rules.
- **Alternatives considered**: Synchronous requests would weaken current responsiveness and failure handling; adding a new workflow/service layer would violate the repository’s domain-model direction; a new provider abstraction is unnecessary for this feature.

## Decision: Read-only career context

- **Decision**: Serialize career applications, statuses, events, and explicitly selected optional records as analysis data only. Recommendations never mutate career records.
- **Rationale**: This matches the specification and protects job-search history from unintended AI actions.
- **Alternatives considered**: Tool calls or automatic task/status creation are explicitly out of scope and would introduce larger authorization and audit risks.

## Decision: Rails-native UI integration

- **Decision**: Extend the existing reports AI conversation form/component and add career links/forms using current Rails routes, ViewComponents, Turbo, and semantic controls.
- **Rationale**: The project constitution requires reuse of established components and Rails conventions.
- **Alternatives considered**: A standalone career dashboard chat would fragment the user experience and duplicate the existing chat UI.
