<!--
Sync Impact Report
- Version change: 1.3.0 -> 2.0.0
- Modified principles:
  - II. Domain Rules Belong in the Domain -> Rich Rails-Native Domain Model
  - III. Test Behavior at Its Boundary -> Test Behavior at Its Boundary
  - IV. Accessible, Consistent User Experience -> Consistent, Accessible Component UI
  - V. Simple, Reviewable Changes -> Rails-Native Evolutionary Design
- Added sections: Resource-Oriented Interfaces; Shallow Asynchronous Adapters;
  Pragmatic Callback Use; Existing Code as a Design Reference; Machine-Enforced Quality
  Gates; Security and Data Safety emphasis in Technical Constraints
- Removed sections: none
- Follow-up TODOs: ratification date requires project-owner confirmation;
  AGENTS.md and STYLE.md guidance proposed in the amendment summary but intentionally
  not changed by this constitution-only command
-->

# Open Budget Constitution

## Core Principles

### I. Financial Correctness Is Non-Negotiable

Operations involving balances, planned transactions, actual transactions, transfers,
liabilities, funding, income, expenses, dates, statuses, carryovers, or related
financial state MUST preserve their financial meaning. Planned spending MUST remain
distinct from actual spending. Financial state transitions involving multiple related
writes MUST be atomic, with the transaction boundary located with the domain operation
whose consistency it protects. Persisted monetary calculations MUST use precise
database-backed numeric handling; floating-point arithmetic MUST NOT be used for
persisted money calculations. Schema and behavior changes MUST protect existing
financial data and include normal, boundary, and migration-impact verification.
Rationale: users make financial decisions from these calculations, so plausible-looking
but incorrect results are unacceptable.

### II. Rich Rails-Native Domain Model

Business behavior and invariants MUST live in the model or explicit domain object that
owns the concept. Controllers MUST invoke intention-revealing domain APIs directly
when those APIs express the operation, such as `execute`, `close`, `activate`, or
`transfer_to`. Service objects, form objects, workflow objects, and other plain Ruby
objects MAY represent useful concepts or clarify orchestration, but MUST NOT become a
mandatory intermediate layer between controllers and domain objects. A database
transaction, multiple method calls, or method complexity alone does NOT justify a
service object. Repositories, mandatory interactors, command layers, and equivalent
abstractions MUST NOT be introduced without a concrete requirement that Rails and
Active Record do not adequately address. Rationale: behavior is easiest to reason
about when its invariants and ownership remain explicit in the domain model.

### III. Resource-Oriented Rails Interfaces

Web interactions SHOULD be modeled as CRUD operations on meaningful resources. When
behavior does not fit an existing resource, developers MUST first consider whether it
represents another domain or interaction resource before adding custom controller
member actions. Resource-oriented design is a modeling tool, not ceremony, and MUST
NOT be applied when it makes the domain less clear. Controllers MUST primarily load
request-scoped state, authorize, handle parameters, invoke domain APIs, select response
formats, and render or redirect. Controllers MUST NOT own business rules.
Rationale: meaningful resources keep HTTP interfaces aligned with domain concepts while
keeping request coordination separate from business behavior.

### IV. Test Behavior at Its Boundary

Feature and behavior changes MUST use test-first development where practical: write or
update a focused test, confirm the expected failure, implement the smallest passing
change, and refactor with tests passing. Tests MUST verify behavior at the most
appropriate boundary. Model and domain-object tests MUST verify domain rules and state
transitions. Request, controller, and integration tests MUST verify HTTP and workflow
contracts. System tests MUST be reserved for user-visible behavior that cannot be
adequately verified at a lower boundary. Tests MUST remain understandable and
behavior-focused; explicit Arrange/Act/Assert headings or comments are not required.
Existing Active Record fixtures MUST be preferred for shared and representative data;
developers MUST inspect suitable fixtures before creating new test records. Inline
records remain appropriate when the state is specific to the scenario or fixtures
would obscure the behavior. The relevant test suite MUST pass before merge.
Rationale: boundary-appropriate tests protect behavior without imposing ceremony that
reduces clarity.

### V. Consistent, Accessible Component UI

User-facing screens MUST preserve clear labels, semantic markup, meaningful status
indicators, keyboard-accessible controls, readable contrast, responsive layouts, and
accessible interaction states. Repeated UI patterns MUST use an existing project
component when one provides the needed behavior. Views SHOULD compose established
components rather than recreate raw styled controls. Shared components own reusable
appearance, interaction states, accessibility behavior, and semantic markup; feature
views MAY use Tailwind directly for layout and composition without recreating
established component styling. When a canonical component needs improvement, the
canonical component SHOULD be improved so the change propagates consistently.

shadcn/ui is the upstream design reference for reusable interface patterns. When no
appropriate project component exists, developers MUST inspect the closest official
shadcn/ui component, understand its hierarchy, states, semantics, accessibility, and
keyboard interactions, and adapt the relevant design into a Rails-native component
using Tailwind, Hotwire, and Stimulus as appropriate. React-specific implementation
architecture MUST NOT be copied blindly. Project components become the canonical
implementations and SHOULD be reused throughout the application. Styling MUST use
semantic design tokens; direct color duplication requires justification.
Rationale: a shared component architecture prevents UI drift, including drift caused
by AI-assisted development, while preserving Rails-native implementation choices.

### VI. Shallow Asynchronous Adapters

Background jobs SHOULD load or receive the relevant domain objects and delegate
substantive behavior to intention-revealing synchronous domain APIs. Business rules
MUST NOT primarily live inside job classes. Synchronous/asynchronous pairs MAY be
provided when they clarify the API, but naming conventions such as `process_now` and
`process_later` are guidance rather than requirements. Rationale: jobs are delivery
adapters and should not create a second, divergent source of domain behavior.

### VII. Pragmatic Callback Use

Rails callbacks MAY enforce lifecycle behavior intrinsic to the model. Callbacks that
mutate unrelated domain state, perform remote operations, cause difficult-to-discover
effects, or introduce substantial non-local behavior MUST have a concrete justification.
External or expensive effects SHOULD occur after commit and/or through background jobs
when appropriate. Rationale: callbacks are useful for local lifecycle invariants, but
non-local effects need explicit boundaries and review.

### VIII. Rails-Native Evolutionary Design

The application MUST prefer Rails, Active Record, Hotwire, and established project
dependencies before introducing parallel frameworks, architectural layers, or
libraries. New dependencies and abstractions MUST solve a concrete current problem.
The project MUST NOT adopt enterprise, Clean Architecture, or non-Rails ceremony solely
because it is fashionable or common in another ecosystem. Implementations MUST use the
simplest design that correctly represents documented behavior and MUST NOT build
speculative abstractions for hypothetical requirements. Rationale: evolutionary design
keeps a personal finance application understandable and adaptable.

### IX. Existing Code as a Design Reference

Before introducing a model structure, concern, domain object, controller pattern, UI
component, test structure, abstraction, dependency, or job pattern, developers and
agents SHOULD search for the closest coherent repository example. Existing code is
guidance, not absolute law: financial correctness, security, data safety, and other
constitutional invariants take precedence, and conflicts MUST be identified explicitly.
Rationale: local consistency reduces accidental architectural drift without freezing
the codebase in place.

## Technical Constraints

The application MUST remain compatible with Ruby on Rails 8.1, PostgreSQL, and the
repository's configured test and asset toolchain unless an approved amendment or
feature plan explicitly changes that baseline. Database changes MUST use reversible
migrations where practical, document migration impact, and preserve existing user
financial data. Authentication and authorization MUST protect user-owned financial
data. Logs, fixtures, tests, and error messages MUST NOT expose passwords, tokens, or
other secrets. Security-sensitive changes MUST receive security-tooling or equivalent
documented review. Accessibility and semantic design-token requirements apply to all
user-facing interfaces.

## Development Workflow

Feature work MUST follow the repository's Spec Kit sequence when the change is more
than a local defect fix: specify, clarify when needed, plan, generate tasks, then
implement. Each plan MUST identify affected domain rules, data changes, user-visible
behavior, and verification steps. Features SHOULD be delivered as focused vertical
slices with explicit acceptance criteria. Pull requests MUST explain the behavior
changed, tests run, migration impact, and known follow-up.

Before merge, applicable repository quality checks MUST pass, including the Rails test
suite, Herb linting for modified HTML/ERB views, and security analysis for
security-sensitive changes. Ruby linting, dependency vulnerability checks, secret
detection, and other configured checks MUST be run when applicable. CI failures for
required checks MUST block merge. New tooling SHOULD be added only when it addresses a
concrete Open Budget need. Reviewers MUST reject violations of financial correctness,
data safety, security, or required test coverage unless an explicit exception records
the violated rule, reason, risk, approver, and expiration or follow-up condition.

## Governance

This constitution defines durable project invariants and architectural principles. It
supersedes conflicting practices unless amended. Detailed coding conventions belong in
STYLE.md, and operational instructions for coding agents belong in AGENTS.md; neither
document may weaken this constitution.

Amendments MUST be proposed as a change to this file, include a Sync Impact Report,
explain affected principles and migration needs, and receive project-owner approval.
The amendment MUST update the version and last-amended date. MAJOR changes remove or
redefine principles or otherwise break existing constitutional obligations. MINOR
changes add principles, sections, or material guidance. PATCH changes clarify wording,
fix errors, or make non-semantic refinements. When uncertain, the amendment proposal
MUST explain the selected bump and its compatibility impact.

Every feature plan and pull-request review MUST check applicable principles. The
constitution MUST be reviewed whenever the technology baseline, data model, security
model, or development workflow materially changes. Compliance review SHOULD use
machine-enforced checks where practical. Exceptions require the rule, reason, risk,
approver, and expiration or follow-up condition.

**Version**: 2.0.0 | **Ratified**: TODO(RATIFICATION_DATE): confirm original adoption date | **Last Amended**: 2026-08-22
