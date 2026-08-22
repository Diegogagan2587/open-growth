<!--
Sync Impact Report
- Version change: 1.3.0 -> 2.0.0
- Modified principles:
  - II. Domain Rules Belong in the Domain -> Rich Rails-Native Domain Model
  - III. Test Behavior at Its Boundary -> Test Behavior at Its Boundary
  - IV. Accessible, Consistent User Experience -> Consistent, Accessible Component UI
  - V. Simple, Reviewable Changes -> Rails-Native Evolutionary Design
- Added principle:
  - III. Resource-Oriented Rails Interfaces
- Added or strengthened guidance:
  - atomic financial state transitions
  - Rails-native domain APIs and service-object boundaries
  - shallow asynchronous delegation
  - pragmatic callback use
  - component-based UI consistency and shadcn/ui reference workflow
  - machine-enforced quality gates
  - security and data-safety requirements
- Removed standalone principles:
  - Shallow Asynchronous Adapters
  - Pragmatic Callback Use
  - Existing Code as a Design Reference
- Relocated guidance:
  - asynchronous-job and callback guidance consolidated into Rich Rails-Native Domain Model
  - repository-pattern discovery belongs in AGENTS.md
  - detailed implementation and coding conventions belong in STYLE.md
- Follow-up TODOs:
  - ratification date requires project-owner confirmation
  - define AGENTS.md operational guidance
  - define STYLE.md coding and implementation conventions
-->

# Open Budget Constitution

## Core Principles

### I. Financial Correctness Is Non-Negotiable

Operations involving balances, planned transactions, actual transactions, transfers,
liabilities, funding, income, expenses, dates, statuses, carryovers, or related
financial state MUST preserve their financial meaning. Planned spending MUST remain
distinct from actual spending.

Financial state transitions involving multiple related writes MUST be atomic, with the
transaction boundary located with the domain operation whose consistency it protects.

Persisted monetary calculations MUST use precise database-backed numeric handling;
floating-point arithmetic MUST NOT be used for persisted money calculations. Schema and
behavior changes MUST protect existing financial data and include normal, boundary, and
migration-impact verification.

Rationale: users make financial decisions from these calculations, so plausible-looking
but incorrect results are unacceptable.

### II. Rich Rails-Native Domain Model

Business behavior and invariants MUST live in the model or explicit domain object that
owns the concept. Controllers SHOULD invoke intention-revealing domain APIs directly
when those APIs naturally express the operation, such as `execute`, `close`,
`activate`, or `transfer_to`.

Service objects, form objects, workflow objects, and other plain Ruby objects MAY
represent useful concepts or clarify orchestration, but MUST NOT become a mandatory
intermediate layer between controllers and domain objects. A database transaction,
multiple method calls, or method complexity alone does NOT justify introducing a
service object.

Repositories, mandatory interactors, command layers, and equivalent abstractions MUST
NOT be introduced without a concrete requirement that Rails and Active Record do not
adequately address.

Background jobs SHOULD remain shallow adapters around domain behavior. Substantive
business rules SHOULD live in domain objects rather than primarily inside job classes,
with jobs delegating to intention-revealing synchronous APIs when practical.

Rails callbacks MAY enforce lifecycle behavior intrinsic to the model. Callbacks that
mutate unrelated domain state, perform remote operations, introduce substantial
non-local behavior, or make important effects difficult to discover MUST have concrete
justification. Expensive or external effects SHOULD occur after commit and through
background jobs when appropriate.

Rationale: behavior is easiest to reason about when ownership, invariants, transaction
boundaries, and lifecycle behavior remain close to the domain concept they describe.

### III. Resource-Oriented Rails Interfaces

Web interactions SHOULD be modeled as CRUD operations on meaningful resources. When
behavior does not fit an existing resource, developers MUST first consider whether it
represents another domain or interaction resource before adding custom controller
member actions.

Resource-oriented design is a modeling tool, not ceremony, and MUST NOT be applied when
it makes the domain less clear.

Controllers MUST primarily coordinate request and response concerns, including loading
request-scoped state, authorization, parameter handling, invoking domain APIs, selecting
response formats, rendering, and redirecting. Controllers MUST NOT become the primary
owners of business rules.

Rationale: meaningful resources keep HTTP interfaces aligned with domain concepts while
keeping request coordination separate from business behavior.

### IV. Test Behavior at Its Boundary

Feature and behavior changes MUST use test-first development unless the change cannot
reasonably be driven through an automated test. Any exception MUST be identified in the
implementation or review with its reason.

Test-first development means writing or updating a focused test, confirming that it
fails for the expected reason, implementing the smallest change that makes it pass, and
then refactoring with tests passing.

Domain rules and state transitions MUST have focused automated coverage, normally
through model or domain-object tests. Request, controller, and integration tests MUST
verify HTTP and workflow contracts. System tests MUST be reserved for user-visible
behavior whose interaction cannot be adequately verified at a lower boundary.

Tests MUST remain understandable and behavior-focused. Setup, behavior under test, and
expected outcomes MUST be easy to distinguish, but explicit Arrange/Act/Assert headings
or comments are not required.

Existing Active Record fixtures MUST be preferred for shared and representative data.
Developers MUST inspect suitable fixtures before introducing new fixture data or
creating equivalent records inline. Inline records remain appropriate when the state is
specific to the scenario or fixture use would obscure the behavior.

The relevant test suite MUST pass before merge.

Rationale: boundary-appropriate tests protect behavior without creating redundant
coverage or imposing ceremony that reduces clarity.

### V. Consistent, Accessible Component UI

User-facing screens MUST preserve clear labels, semantic markup, meaningful status
indicators, keyboard-accessible controls, readable contrast, responsive layouts, and
accessible interaction states.

Open Budget deliberately uses a shared component system as a consistency boundary,
including during AI-assisted development. Repeated UI patterns MUST use an existing
project component when one provides the needed behavior. Views SHOULD compose
established components rather than recreate raw styled controls.

Shared components own reusable appearance, interaction states, accessibility behavior,
and semantic markup. Feature views MAY use Tailwind directly for layout and composition
without independently recreating established component styling.

When a canonical component needs improvement, developers SHOULD improve the canonical
component so the enhancement propagates consistently rather than introducing
view-specific alternatives for the same UI concept.

shadcn/ui is the upstream design reference for reusable interface patterns. When no
appropriate project component exists, developers MUST inspect the closest official
shadcn/ui component and understand its visual hierarchy, states, semantics,
accessibility requirements, keyboard behavior, and interaction model before adapting
the relevant design into a Rails-native component.

Adapted components MUST use the project's Rails, Tailwind, Hotwire, and Stimulus
conventions as appropriate. React-specific implementation architecture MUST NOT be
copied blindly.

Once introduced, the project-owned component becomes the canonical implementation and
SHOULD be reused throughout the application.

Styling MUST use semantic design tokens. Direct duplication of raw colors or other
established visual values requires justification.

Rationale: a shared component architecture prevents visual and interaction drift while
allowing the application to benefit from a mature design reference without coupling its
implementation to React.

### VI. Rails-Native Evolutionary Design

The application MUST prefer Rails, Active Record, Hotwire, and established project
dependencies before introducing parallel frameworks, architectural layers, or
libraries.

New dependencies and abstractions MUST solve a concrete current problem. The project
MUST NOT adopt enterprise architecture, Clean Architecture, repository layers,
interactor layers, or non-Rails ceremony solely because those patterns are fashionable
or common in another ecosystem.

Implementations MUST use the simplest design that correctly represents documented
behavior. Speculative abstractions for hypothetical future requirements MUST NOT be
introduced without a concrete present need.

Existing project architecture and conventions SHOULD evolve coherently rather than
being replaced with locally novel patterns without justification.

Rationale: Rails-native evolutionary design keeps a personal finance application
understandable, maintainable, and adaptable while avoiding accidental architectural
complexity.

## Technical Constraints

The application MUST remain compatible with Ruby on Rails 8.1, PostgreSQL, and the
repository's configured test and asset toolchain unless an approved constitution
amendment or feature plan explicitly changes that baseline.

Database changes MUST use reversible migrations where practical, document migration
impact, and preserve existing user financial data.

Authentication and authorization MUST protect user-owned financial data. Logs,
fixtures, tests, and error messages MUST NOT expose passwords, tokens, credentials, or
other secrets.

Security-sensitive changes MUST receive review using the repository's configured
security tooling or an equivalent documented process.

Accessibility and semantic design-token requirements apply to all user-facing
interfaces.

## Development Workflow

Feature work MUST follow the repository's Spec Kit sequence when the change is more
than a local defect fix: specify, clarify when needed, plan, generate tasks, then
implement.

Each plan MUST identify affected domain rules, data changes, user-visible behavior, and
verification steps. Features SHOULD be delivered as focused vertical slices with
explicit acceptance criteria.

Pull requests MUST explain:

* the behavior changed;
* tests and verification performed;
* migration or data impact;
* security impact when applicable;
* known follow-up work.

Before merge, applicable repository quality checks MUST pass, including the Rails test
suite, Herb linting for modified HTML/ERB views, and security analysis for
security-sensitive changes.

Ruby linting, dependency vulnerability checks, secret detection, system tests, and
other configured checks MUST run when applicable. Required CI failures MUST block
merge.

Project requirements that can reasonably be enforced mechanically SHOULD be enforced
through CI or repository tooling rather than relying exclusively on written
instructions. New tooling SHOULD be added only when it addresses a concrete Open Budget
need.

Operational instructions for coding agents SHOULD require agents to inspect existing
repository patterns before introducing new structures, components, abstractions, test
patterns, dependencies, or job patterns. Those instructions belong in `AGENTS.md`
rather than defining additional constitutional principles.

Reviewers MUST reject violations of financial correctness, data safety, security, or
required test coverage unless an explicit exception records the violated rule, reason,
risk, approver, and expiration or follow-up condition.

## Governance

This constitution defines durable project invariants and architectural principles. It
supersedes conflicting practices unless amended.

Detailed coding and implementation conventions belong in `STYLE.md`. Operational
instructions for coding agents belong in `AGENTS.md`. Neither document may weaken or
override this constitution.

Amendments MUST be proposed as changes to this file, include a Sync Impact Report,
explain affected principles and migration needs, and receive project-owner approval.

The amendment MUST update the version and last-amended date.

Version changes follow these rules:

* **MAJOR** changes remove or redefine principles or otherwise break existing
  constitutional obligations.
* **MINOR** changes add principles, sections, or materially expand existing guidance
  without breaking previous obligations.
* **PATCH** changes clarify wording, correct errors, or make non-semantic refinements.

When the appropriate version change is uncertain, the amendment proposal MUST explain
the selected bump and its compatibility impact.

Every feature plan and pull-request review MUST check applicable constitutional
principles. The constitution MUST be reviewed whenever the technology baseline, data
model, security model, or development workflow materially changes.

Compliance review SHOULD use machine-enforced checks where practical.

Exceptions MUST record the violated rule, reason, risk, approver, and expiration or
follow-up condition.

**Version**: 2.0.0 | **Ratified**: 2026-08-22 | **Last Amended**: 2026-08-22
