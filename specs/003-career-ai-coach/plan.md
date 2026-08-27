# Implementation Plan: Career AI Coach

**Branch**: `003-career-ai-coach` | **Date**: 2026-08-27 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/003-career-ai-coach/spec.md`

## Summary

Extend the existing `Reporting::Conversation` financial AI chat into a shared, domain-aware chat that supports career analysis. Add a persisted analysis domain/context selection, Rails-native domain behavior for producing an account-scoped career snapshot, and prompt/instruction routing for structured career coaching. Reuse the existing controllers, turns, background job, usage limits, Turbo updates, and chat component; add career entry points and domain-aware UI copy. Career analysis remains read-only.

## Technical Context

**Language/Version**: Ruby 3.x with Rails 8.1.3

**Primary Dependencies**: Active Record, PostgreSQL, Hotwire/Turbo, Stimulus, ViewComponent, OpenAI Ruby client 0.80.x, Minitest

**Storage**: PostgreSQL; existing `reporting_conversations`, `reporting_turns`, `reporting_usage_events`, and career tables

**Testing**: Rails/Minitest model/domain-object, controller/integration, component, and focused system tests where interaction requires it

**Target Platform**: Server-rendered Rails web application with responsive browser UI

**Project Type**: Rails monolith web application

**Performance Goals**: First AI response within the existing 60-second product target under normal provider availability; snapshot construction bounded to account-scoped records and documented limits

**Constraints**: Preserve financial/career account isolation, read-only analysis, existing AI quotas and failure handling, no new AI provider or chat framework, no automatic career record mutations, accessible component-based UI

**Scale/Scope**: One shared conversation model for financial and career domains; career analysis defaults to applications/statuses/events and supports explicitly selected optional context; no external job-board ingestion in this slice

## Constitution Check

*GATE: PASS before Phase 0 and after Phase 1 design.*

- Financial correctness: PASS. Financial snapshot behavior remains unchanged; domain selection prevents accidental cross-domain data mixing.
- Rich Rails-Native Domain Model: PASS. Conversation domain/context behavior and career analysis behavior belong to `Reporting::Conversation` and explicit reporting domain objects under `app/models/reporting`; controllers only coordinate requests.
- Resource-Oriented Rails Interfaces: PASS. Existing conversation and turn resources remain the HTTP boundary; career entry points create/open the same conversation resource.
- Test Behavior at Its Boundary: PASS. Add model/domain-object, snapshot/prompt, request, component, and end-to-end tests at their respective boundaries.
- Consistent, Accessible Component UI: PASS. Extend the existing analysis chat component and reuse project UI components; provide domain labels, empty/loading/error states, and semantic controls.
- Rails-Native Evolutionary Design: PASS. Reuse Active Record, existing jobs, controllers, Turbo, and OpenAI integration; new business rules live in models/domain objects, with no new service-folder workflow layer or dependency introduced.
- Security/data safety: PASS. Scope all queries by account and membership-owned conversation; do not send unauthorized records or secrets to the provider.

## Phase 0: Research Summary

Research findings are recorded in [research.md](research.md). All technical unknowns are resolved: the existing reporting conversation is the persistence boundary, snapshots are the provider context boundary, and the existing OpenAI job pipeline is the execution boundary.

## Phase 1: Design Summary

- [data-model.md](data-model.md) defines the domain-aware reporting conversation and career analysis snapshot data.
- [contracts/shared-chat.md](contracts/shared-chat.md) defines the request, response, authorization, and UI behavior contract.
- [quickstart.md](quickstart.md) defines runnable validation scenarios.

## Project Structure

```text
app/
├── models/reporting/conversation.rb
├── models/reporting/analysis_snapshot.rb
├── models/reporting/career_analysis_snapshot.rb
├── models/reporting/analysis_domain.rb
├── services/reporting/answer_question.rb # existing external/provider orchestration only
├── controllers/reports/ai/conversations_controller.rb
├── controllers/reports/ai/turns_controller.rb
├── components/reports/analysis_chat_component.*
├── views/career/dashboard/index.html.erb
└── views/reports/ai/conversations/*
db/migrate/
test/models/reporting/
test/services/reporting/
test/controllers/reports/ai/
test/components/reports/
test/integration/
```

**Structure Decision**: Keep the existing Rails monolith structure, but place new business behavior in Active Record models or explicit domain objects under `app/models/reporting`. The existing `Reporting::AnswerQuestion` location is retained only as a compatibility boundary for provider/job orchestration; it must delegate domain decisions and snapshot construction rather than own them. No new business-logic service under `app/services` is planned. Existing career models remain the source of truth for career records.

## Implementation Sequencing

1. Add conversation domain/context persistence and model validations/defaults.
2. Add reporting domain objects/model APIs for career snapshot serialization with account scoping, date filtering, default/optional context selection, and low-data metadata.
3. Update the existing provider orchestration boundary to delegate to conversation/domain APIs for financial or career context/instructions while preserving usage, quota, failure, and read-only guarantees.
4. Extend shared chat creation and display flows with domain selection and career entry points.
5. Add boundary tests and run the focused suite plus applicable Rails quality checks.

## Complexity Tracking

No constitution violations or new architectural layers require justification.
