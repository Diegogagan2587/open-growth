# Feature Specification: Career AI Coach

**Feature Branch**: `003-career-ai-coach`

**Created**: 2026-08-25

**Status**: Draft

**Input**: User description: "$speckit-specify the chat is super useful for financial stuff; extend the current chat/AI capability to analyze career job applications, identify where the user is getting stuck, and provide feedback on how to improve their chances of getting a job."

## Clarifications

### Session 2026-08-27

- Q: Which career information should the AI analyze by default? → A: Applications, statuses, and timeline events by default; profile, notes, documents, tasks, and meetings only when explicitly requested.
- Q: Should each career analysis automatically create a saved conversation that the user can revisit and continue later? → A: Automatically save each analysis as a revisitable career conversation.
- Q: What time range should a career analysis cover by default? → A: All recorded applications by default, with an optional date-range filter.
- Q: Should users be able to turn an AI recommendation into a career task? → A: Recommendations remain informational; users create tasks manually.
- Q: How should the AI present the career analysis? → A: Structured sections for funnel snapshot, bottleneck, evidence, recommendations, limitations, and next steps, followed by conversational follow-up support.
- Q: Should career analysis extend the existing AI chat so the same chat experience supports both career and financial analysis? → A: Yes; extend the existing chat to support both domains.

## User Scenarios & Testing

### User Story 1 - Understand the Application Funnel (Priority: P1)

As a job seeker, I want an AI analysis of my application history so I can understand how my search is progressing and where candidates are being lost in the process.

**Why this priority**: The user needs a reliable picture of the pipeline before deciding what to change. Application volume, stage progression, and time spent in stages are the foundation for useful coaching.

**Independent Test**: With a career account containing applications at multiple stages and dated events, request an analysis and verify that it summarizes volume, stage conversion, time-to-stage, stalled applications, and data limitations using only that account’s records.

**Acceptance Scenarios**:

1. **Given** applications with stage history and dates, **when** the user requests career analysis, **then** the result summarizes application counts, progression between stages, response rates where measurable, and time spent at each stage.
2. **Given** applications stalled in one or more stages, **when** the analysis is generated, **then** it identifies the likely bottleneck, names the evidence supporting it, and distinguishes observations from hypotheses.
3. **Given** too little or incomplete history to support a conclusion, **when** the user requests analysis, **then** the result says what cannot be inferred and suggests which records or events would make the analysis more useful.
4. **Given** applications belonging to another account, **when** the user requests analysis, **then** those records are excluded from both the analysis context and the response.

### User Story 2 - Get Actionable Search Feedback (Priority: P1)

As a job seeker, I want practical feedback based on my funnel patterns so I can choose the next actions most likely to improve my search.

**Why this priority**: Analysis has value only when it helps the user change behavior. Recommendations should connect directly to observed bottlenecks such as insufficient applications, weak screening conversion, or stalled follow-up.

**Independent Test**: Given representative career history, request coaching and verify that the response provides prioritized, specific actions tied to evidence, with no guarantee of employment or unsupported certainty.

**Acceptance Scenarios**:

1. **Given** low application volume and otherwise insufficient data, **when** coaching is requested, **then** the response explains that more qualified applications may increase opportunities while avoiding a promise of a particular outcome.
2. **Given** many applications but few screening or interview transitions, **when** coaching is requested, **then** the response focuses on likely application-quality, targeting, resume, or role-fit experiments rather than simply telling the user to apply more.
3. **Given** a long delay at a known stage, **when** coaching is requested, **then** the response suggests stage-specific actions such as follow-up, preparation, clarification, or closing stale applications, and explains the reasoning.
4. **Given** a recommendation, **when** the user reviews it, **then** each recommendation includes a priority, an intended outcome, and the evidence or assumption behind it.

### User Story 3 - Discuss the Analysis Conversationally (Priority: P2)

As a job seeker, I want to ask follow-up questions about my career analysis so I can explore possible causes and decide which experiment to try next.

**Why this priority**: Career searches contain context that aggregate metrics cannot capture. A conversation lets the user challenge assumptions, add context, and request a narrower analysis.

**Independent Test**: Open a career analysis conversation in the existing shared AI analysis chat, ask a follow-up question, and verify that the response uses the same account-scoped career context, clearly labels uncertainty, and remains read-only unless the user separately changes a career record.

**Acceptance Scenarios**:

1. **Given** an existing career analysis, **when** the user asks a follow-up question, **then** the response references relevant applications, events, tasks, and profile context without requiring the user to restate the available data.
2. **Given** the user supplies additional context that is not recorded, **when** the user asks for revised feedback, **then** the response treats that context as user-provided information and distinguishes it from measured application history.
3. **Given** the AI cannot determine the cause of a pattern, **when** the user asks for certainty, **then** it explains competing hypotheses and proposes a measurable experiment rather than presenting a guess as fact.
4. **Given** the AI suggests changing an application, task, event, document, or profile record, **when** the response is shown, **then** it asks the user to perform or approve that change separately and does not modify the record automatically.

## Edge Cases

- A user has no applications or only saved/researching applications; the system provides a useful baseline and states that conversion conclusions are unavailable.
- Applications have missing `applied_on`, event dates, or inconsistent stage ordering; the analysis identifies the missing or conflicting data and avoids false precision.
- A single application dominates the dataset; the analysis warns that conclusions may not generalize.
- The user has a high application count but no recorded events after applying; the system distinguishes missing tracking from evidence of failure.
- An application remains in a stage longer than typical history but has a future interview or task; the system must not label it abandoned solely because of elapsed time.
- The AI provider is unavailable, disabled, rate-limited, or returns an invalid response; the user receives an actionable explanation and career records remain unchanged.
- Sensitive profile or application notes contain personal information; the analysis must use only the user’s authorized account data and avoid exposing it to another account or conversation.
- The user asks for a guaranteed probability of getting hired; the system explains that the analysis can identify patterns and experiments but cannot guarantee an outcome.

## Requirements

### Functional Requirements

- **FR-001**: The system MUST allow an authenticated user to request an on-demand career analysis from the existing shared AI analysis chat in the career section, MUST support an optional date-range filter, and MUST save the result as a revisitable shared analysis conversation that can also support financial analysis.
- **FR-002**: The analysis MUST use only career records the user is authorized to access in the current account. Applications, recorded statuses, and timeline events MUST be included by default; tasks, meetings, documents/notes, and profile information MUST be included only when the user explicitly requests or selects them.
- **FR-003**: The analysis MUST summarize application volume, current stage distribution, progression between stages, measurable response/conversion rates, and elapsed time in stages when sufficient data exists.
- **FR-004**: The analysis MUST identify potential bottlenecks or stalled stages and provide the supporting observations, assumptions, and limitations for each conclusion.
- **FR-005**: The system MUST distinguish measured facts, user-provided context, hypotheses, and recommendations in the AI response.
- **FR-006**: The system MUST provide prioritized, specific next actions connected to the identified pattern, including the intended outcome and a reason for each action.
- **FR-007**: Recommendations MUST account for both application volume and stage conversion; the system MUST NOT treat “apply more” as the universal remedy.
- **FR-008**: The system MUST support follow-up questions within a saved career analysis conversation in the existing shared AI analysis chat while preserving the same account scope and relevant analysis context.
- **FR-009**: The system MUST make career analysis and conversation responses read-only with respect to applications, events, tasks, meetings, documents, and profile records. Recommendations remain informational; users create or update career tasks and other records manually through separate existing workflows.
- **FR-010**: The system MUST communicate uncertainty, incomplete tracking, small sample sizes, and competing explanations rather than presenting unsupported causal claims or guaranteed hiring probabilities.
- **FR-011**: The system MUST provide a useful no-data or low-data response that identifies what is known, what is not measurable, and what information the user can record next.
- **FR-012**: The system MUST handle unavailable, disabled, rate-limited, or failed AI analysis without changing career records and MUST provide an actionable user-facing error.
- **FR-013**: The system MUST apply the existing account’s AI access and usage limits consistently with other AI analysis conversations.
- **FR-014**: The system MUST preserve the analysis conversation and its usage history according to the existing AI conversation data-retention behavior, unless the user explicitly deletes the conversation.
- **FR-015**: The system MUST protect sensitive career information from cross-account access and MUST not include records outside the requested analysis scope.
- **FR-016**: The initial analysis MUST present a structured report containing a funnel snapshot, bottleneck findings, supporting evidence, recommendations, limitations, and next steps before offering conversational follow-up.
- **FR-017**: The existing shared AI analysis chat MUST preserve the selected analysis domain and context for each conversation, and MUST NOT mix financial records into career analysis or career records into financial analysis unless the user explicitly requests a cross-domain analysis.

### Key Entities

- **Career analysis conversation**: A user-owned, revisitable conversation in the existing shared AI analysis chat containing a selected analysis domain, analysis scope, generated findings, follow-up questions, and AI responses.
- **Career analysis context**: The account-scoped snapshot or query result of applications, events, pipeline stages, timing, tasks, meetings, documents/notes, and profile data used to answer a request.
- **Career pattern finding**: An observed metric, bottleneck, hypothesis, or limitation identified from the analysis context.
- **Career recommendation**: A prioritized action or measurable experiment tied to a finding, including its rationale and intended outcome.
- **Job application history**: All application records and dated events that describe the user’s search funnel from discovery through outcome; the default analysis scope includes all recorded history unless the user applies a date-range filter.

## Success Criteria

### Measurable Outcomes

- **SC-001**: A user with at least three applications and recorded stage events can request and receive a first career analysis within 60 seconds under normal service availability.
- **SC-002**: In evaluation cases with sufficient data, at least 90% of analyses correctly report application counts and stage counts, and at least 85% correctly identify the intentionally seeded bottleneck stage.
- **SC-003**: At least 90% of evaluated recommendations identify the evidence or assumption behind the recommendation and propose a concrete next action or experiment.
- **SC-004**: In usability testing, at least 85% of users can identify their primary suspected bottleneck and one next action after reviewing an analysis without opening another section of the application.
- **SC-005**: 100% of tested analysis requests exclude records from other accounts and leave career records unchanged.
- **SC-006**: 100% of low-data and incomplete-data test cases disclose the relevant limitation instead of inventing a conversion rate, stage duration, or hiring probability.
- **SC-007**: Follow-up questions retain the original account scope and analysis context for 100% of tested conversations.
- **SC-008**: When the AI provider is unavailable or a request limit is reached, users receive an actionable failure message and no career record is modified in 100% of tested cases.
- **SC-009**: 100% of successful first analyses in acceptance testing contain the required structured sections and clearly separate evidence, hypotheses, recommendations, limitations, and next steps.

## Assumptions

- Analysis is requested on demand from the career dashboard or a job-application context; automatic recurring analysis is out of scope for this slice. All recorded application history is included by default, with an optional date-range filter.
- Existing account authentication, authorization, AI access controls, usage limits, conversation storage, and chat presentation conventions are reused.
- The existing shared AI analysis chat is the single conversational experience for financial and career analysis; the career feature extends it with career context rather than introducing a separate chat system.
- Existing applications, statuses, and dated events are the default source of funnel data; profile, notes, documents, tasks, and meetings are optional context selected by the user. The system does not infer unrecorded applications or events.
- The initial release provides guidance and experiments, not automated job submissions, resume edits, outreach, status changes, or task creation from recommendations.
- Hiring outcomes remain probabilistic and vary by role, market, candidate fit, and tracking quality; the system is a decision-support tool, not an employment predictor.
- Mobile and external job-board integrations are out of scope unless separately specified.
- Users are responsible for reviewing AI feedback and deciding which recommendations to act on.
- The structured first response is the canonical summary; follow-up messages may be conversational but must retain the same evidence and uncertainty boundaries.
