---

description: "Implementation tasks for the Career AI Coach feature"
---

# Tasks: Career AI Coach

**Input**: Design documents from `specs/003-career-ai-coach/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md`

**Organization**: Tasks are grouped by user story. New business behavior belongs in Active Record models or explicit domain objects under `app/models`; `app/services` remains limited to existing provider/external orchestration.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish the implementation/test locations without introducing new dependencies or service layers.

- [ ] T001 Confirm the existing reporting chat, career models, fixtures, and component conventions in `app/models/reporting/`, `app/models/career/`, `test/fixtures/`, and `app/components/reports/analysis_chat_component.*`
- [ ] T002 [P] Create the model/domain-object test locations in `test/models/reporting/` and the request/component test locations in `test/controllers/reports/ai/` and `test/components/reports/`
- [ ] T003 [P] Record the shared-chat domain/context contract and Rails-native placement decisions in `specs/003-career-ai-coach/contracts/shared-chat.md` and `specs/003-career-ai-coach/plan.md`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Add the shared conversation scope required by every user story while preserving existing financial conversations.

- [ ] T004 Write failing model tests for supported analysis domains, default career context, immutable domain/context scope, and membership/account ownership in `test/models/reporting/conversation_test.rb`
- [ ] T005 Write a reversible migration adding `analysis_domain` and career context selection storage with existing rows safely defaulted to `financial` in `db/migrate/20260827000000_add_analysis_scope_to_reporting_conversations.rb`
- [ ] T006 Implement `Reporting::Conversation` domain constants, normalization, validations, and intention-revealing context APIs in `app/models/reporting/conversation.rb`
- [ ] T007 Verify existing financial conversation creation, listing, deletion, usage retention, and immutable date-range behavior remain passing in `test/models/reporting/conversation_test.rb` and `test/controllers/reports/ai/conversations_controller_test.rb`
- [ ] T008 Add focused tests for account/membership authorization and domain isolation at the reporting conversation boundary in `test/models/reporting/conversation_test.rb` and `test/controllers/reports/ai/conversations_controller_test.rb`

**Checkpoint**: Existing financial chat behavior remains intact and every conversation has a stable domain/context scope.

---

## Phase 3: User Story 1 - Understand the Application Funnel (Priority: P1) 🎯 MVP

**Goal**: Allow a user to start a career analysis in the existing shared chat and receive account-scoped funnel data, bottleneck evidence, and limitations.

**Independent Test**: With applications at multiple stages and dated events, create a career conversation, generate its domain snapshot, and verify counts, stages, timing, stalled data, account isolation, and low-data limitations without changing career records.

### Tests for User Story 1

> Write these tests first and confirm they fail for the expected reason before implementation.

- [ ] T009 [P] [US1] Add career conversation creation request tests for domain selection, default date range, optional context, invalid input, and account scoping in `test/controllers/reports/ai/conversations_controller_test.rb`
- [ ] T010 [P] [US1] Add career snapshot domain-object tests for application/status/event serialization, derived stage metrics, date filtering, missing data, future actions, and cross-account exclusion in `test/models/reporting/career_analysis_snapshot_test.rb`
- [ ] T011 [P] [US1] Add provider-boundary tests asserting career conversations receive career context and career instructions without financial records in `test/services/reporting/answer_question_test.rb`

### Implementation for User Story 1

- [ ] T012 [US1] Re-home the existing financial snapshot behavior as `Reporting::AnalysisSnapshot` under `app/models/reporting/analysis_snapshot.rb`, preserving its public output and account/date scoping
- [ ] T013 [US1] Implement `Reporting::CareerAnalysisSnapshot` as an explicit domain object under `app/models/reporting/career_analysis_snapshot.rb` with bounded account-scoped applications, statuses, events, derived funnel metrics, and data-quality metadata
- [ ] T014 [US1] Add explicit optional career context selection handling for profile, notes/documents, tasks, and meetings in `app/models/reporting/conversation.rb` and `app/models/reporting/career_analysis_snapshot.rb`
- [ ] T015 [US1] Add conversation domain APIs that select the financial or career snapshot and expose the immutable analysis scope to the provider boundary in `app/models/reporting/conversation.rb`
- [ ] T016 [US1] Update the existing provider orchestration to delegate snapshot selection and career instructions to conversation/domain APIs while retaining quota, usage, queue, failure, and read-only behavior in `app/services/reporting/answer_question.rb`
- [ ] T017 [US1] Add career-specific first-response instructions requiring funnel snapshot, bottleneck findings, evidence, recommendations, limitations, next steps, fact/hypothesis separation, and no guaranteed hiring outcomes in `app/models/reporting/conversation.rb`
- [ ] T018 [US1] Extend shared conversation creation parameters and UI with accessible financial/career domain controls, date scope, optional career context controls, and validation feedback in `app/controllers/reports/ai/conversations_controller.rb` and `app/views/reports/ai/conversations/index.html.erb`
- [ ] T019 [US1] Update the shared chat component to display the selected domain, scope, career empty-state guidance, and read-only/error messaging using existing UI conventions in `app/components/reports/analysis_chat_component.html.erb` and `app/components/reports/analysis_chat_component.rb`
- [ ] T020 [US1] Add a career dashboard entry point that creates or opens a career conversation through the existing reports AI resource in `app/controllers/career/dashboard_controller.rb` and `app/views/career/dashboard/index.html.erb`
- [ ] T021 [US1] Add request/component assertions for career labels, empty/loading/error states, keyboard-accessible controls, and shared conversation rendering in `test/controllers/reports/ai/conversations_controller_test.rb` and `test/components/reports/analysis_chat_component_test.rb`

**Checkpoint**: User Story 1 is independently demonstrable as the MVP.

---

## Phase 4: User Story 2 - Get Actionable Search Feedback (Priority: P1)

**Goal**: Turn measured funnel patterns into prioritized, evidence-linked recommendations without making changes automatically.

**Independent Test**: Given low volume, weak stage conversion, and a stalled stage in representative career records, verify that the career response recommends different evidence-based experiments, includes intended outcomes and assumptions, and leaves all records unchanged.

### Tests for User Story 2

- [ ] T022 [P] [US2] Add prompt contract tests for volume-versus-conversion reasoning, stage-specific recommendations, priorities, intended outcomes, evidence/assumptions, and no employment guarantees in `test/models/reporting/conversation_test.rb` and `test/services/reporting/answer_question_test.rb`
- [ ] T023 [P] [US2] Add low-data and incomplete-data snapshot tests proving missing conversion rates and hiring probabilities are disclosed rather than invented in `test/models/reporting/career_analysis_snapshot_test.rb`

### Implementation for User Story 2

- [ ] T024 [US2] Add career recommendation instructions and structured response constraints to the reporting domain prompt API in `app/models/reporting/conversation.rb`
- [ ] T025 [US2] Add safe serialization for evidence record identifiers, observations, assumptions, and data limitations in `app/models/reporting/career_analysis_snapshot.rb`
- [ ] T026 [US2] Ensure the existing turn/provider boundary preserves read-only behavior and actionable provider failure messages for career analysis in `app/services/reporting/answer_question.rb` and `app/jobs/reporting/answer_question_job.rb`
- [ ] T027 [US2] Add UI copy and guidance explaining that recommendations are informational and users create tasks or update records manually in `app/components/reports/analysis_chat_component.html.erb`

**Checkpoint**: User Stories 1 and 2 both work independently; analysis identifies patterns and recommends experiments without mutations.

---

## Phase 5: User Story 3 - Discuss the Analysis Conversationally (Priority: P2)

**Goal**: Preserve career context across follow-up turns in the same shared chat while keeping account and domain isolation.

**Independent Test**: Open a saved career conversation, ask a follow-up, supply unrecorded context, and verify the answer retains the original scope, labels uncertainty, and does not alter career records or switch to financial data.

### Tests for User Story 3

- [ ] T028 [P] [US3] Add follow-up tests proving persisted career domain/context is reused across turns and user-provided context is distinguished from measured records in `test/services/reporting/answer_question_test.rb`
- [ ] T029 [P] [US3] Add authorization tests proving another account or membership cannot load or ask questions in a career conversation in `test/controllers/reports/ai/conversations_controller_test.rb` and `test/controllers/reports/ai/turns_controller_test.rb`
- [ ] T030 [P] [US3] Add shared chat component tests for revisitable career conversations, follow-up form state, domain labels, and failed-turn rendering in `test/components/reports/analysis_chat_component_test.rb`

### Implementation for User Story 3

- [ ] T031 [US3] Update conversation history and prompt assembly to use the persisted domain/context APIs for every follow-up while preserving existing history limits in `app/services/reporting/answer_question.rb` and `app/models/reporting/conversation.rb`
- [ ] T032 [US3] Add career-specific follow-up guidance for competing hypotheses, uncertainty, user-provided context, and read-only recommendations in `app/models/reporting/conversation.rb`
- [ ] T033 [US3] Add career links from the job application context to the shared conversation resource while preserving current account authorization in `app/controllers/career/job_applications_controller.rb` and `app/views/career/job_applications/show.html.erb`

**Checkpoint**: All user stories are independently functional through the single shared chat experience.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Verify migration safety, accessibility, security, performance, and documentation across the complete feature.

- [ ] T034 [P] Add migration/backward-compatibility coverage for existing financial conversations and default domain behavior in `test/models/reporting/conversation_test.rb`
- [ ] T035 [P] Add security regression coverage for provider payload account isolation and absence of unauthorized career records in `test/models/reporting/career_analysis_snapshot_test.rb` and `test/services/reporting/answer_question_test.rb`
- [ ] T036 [P] Add or update component/system coverage for responsive layout, semantic labels, keyboard navigation, and visible loading/error states in `test/components/reports/analysis_chat_component_test.rb` and `test/system/`
- [ ] T037 Run the focused feature suite from `specs/003-career-ai-coach/quickstart.md` and resolve failures in the affected model/domain, request, provider-boundary, and component tests
- [ ] T038 Run the full Rails test suite, RuboCop, Brakeman, and configured Herb checks documented in `specs/003-career-ai-coach/quickstart.md`; record any justified test-first exceptions in the implementation review
- [ ] T039 Update `specs/003-career-ai-coach/quickstart.md` if implementation routes, test paths, or user-visible validation steps differ from the delivered behavior

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies; confirms existing boundaries.
- **Foundational (Phase 2)**: Depends on Setup and blocks all user stories because every story uses the persisted conversation domain/context.
- **User Story 1 (Phase 3)**: Depends on Foundational; delivers the MVP.
- **User Story 2 (Phase 4)**: Depends on the shared career snapshot/prompt APIs from US1, but is independently testable with those APIs.
- **User Story 3 (Phase 5)**: Depends on the persisted conversation scope from Foundational and the career prompt/snapshot behavior from US1; it completes shared-chat follow-up behavior.
- **Polish (Phase 6)**: Depends on all delivered story phases.

### User Story Dependencies

- **US1 (P1)**: Starts after Foundational; no dependency on US2 or US3.
- **US2 (P1)**: Uses US1’s career context and response pipeline; no dependency on US3.
- **US3 (P2)**: Uses US1’s persisted career context and US2’s structured prompt behavior.

### Parallel Opportunities

- T009, T010, and T011 can run in parallel after Foundational test fixtures/conventions are understood.
- T012 and T013 can run in parallel after the domain scope is established; T014 and T015 follow their public APIs.
- T022 and T023 can run in parallel.
- T028, T029, and T030 can run in parallel.
- T034, T035, and T036 can run in parallel after story behavior stabilizes.
- Different story phases can be assigned to separate implementers only after their shared domain APIs are agreed and merged.

## Parallel Example: User Story 1

```text
Task T009: Career conversation request tests
Task T010: Career snapshot domain-object tests
Task T011: Provider-boundary career routing tests
```

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Setup and Foundational.
2. Complete US1 tests first, then implement the persisted domain scope, career snapshot, provider delegation, and shared-chat entry point.
3. Validate account isolation, low-data handling, structured response instructions, and unchanged financial chat behavior.
4. Stop and demo the career funnel analysis before adding recommendation refinements or follow-up enhancements.

### Incremental Delivery

1. Deliver US1 as the first usable career analysis slice.
2. Add US2’s evidence-linked recommendation behavior without introducing record mutation.
3. Add US3’s persisted-context follow-up behavior.
4. Run cross-cutting security, accessibility, migration, and full-suite checks.

## Notes

- Every task uses the required checkbox, sequential ID, optional `[P]` marker, story label where applicable, and an exact file path.
- New domain behavior must not be placed in a new `app/services` workflow/service object.
- Existing `app/services/reporting/answer_question.rb` may be edited only as the provider/external orchestration boundary and must delegate business behavior to models/domain objects.
- Tests follow the constitution’s test-first requirement and use existing fixtures where suitable.
