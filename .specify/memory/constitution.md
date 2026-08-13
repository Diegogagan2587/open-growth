<!--
Sync Impact Report
- Version change: 1.0.0 -> 1.1.0
- Modified principles: II. Domain Rules Belong in the Domain -> clarified invariant ownership
- Added sections: none
- Removed sections: none
- Follow-up TODOs: ratification date requires project-owner confirmation
-->

# Open Budget Constitution

## Core Principles

### I. Financial Correctness Is Non-Negotiable

Budget, income, planned-expense, actual-expense, account, loan, and balance
behavior MUST preserve financial meaning across create, update, transfer, apply,
and delete flows. Planned spending MUST remain distinguishable from actual
spending. Changes affecting calculations, carryovers, dates, statuses, or money
values MUST include tests covering normal and boundary cases. Rationale: users
make financial decisions from these calculations, so plausible-looking but
incorrect results are unacceptable.

### II. Domain Rules Belong in the Domain

Business invariants MUST live in the model or explicit domain object whose state
they constrain. Invariants MUST NOT be owned by workflow services, controllers,
views, or JavaScript. Services MUST only orchestrate complex workflows involving
multiple domain objects, transactions, or external effects; they MUST delegate
state validity to the relevant models or domain objects. Controllers MUST
coordinate requests and responses; views MUST present state. New behavior MUST
reuse an existing domain object when its responsibility matches, or document why
a new domain object is needed. Rationale: explicit invariant ownership supports
domain-modeling practice, prevents contradictory rules, and keeps workflows
reusable.

### III. Test Behavior at Its Boundary

Every behavior change MUST add or update the narrowest meaningful automated test.
Model and service tests MUST cover domain rules; controller and integration tests
MUST cover request and workflow contracts; system tests MUST cover user-visible
flows that cannot be validated at a lower boundary. The full relevant test suite
MUST pass before merge. Rationale: boundary-focused tests expose regressions while
keeping feedback fast.

### IV. Accessible, Consistent User Experience

User-facing screens MUST remain usable on supported screen sizes and preserve
clear labels, meaningful status indicators, keyboard-accessible controls, and
readable contrast. Shared navigation and repeated UI patterns MUST use existing
ViewComponents or shared partials when available. Styling MUST use semantic
design tokens and the established Tailwind/shadcn conventions; direct color
duplication requires justification. Rationale: budget work is frequent and
detail-heavy, so clarity and consistency directly affect user accuracy.

### V. Simple, Reviewable Changes

Implementations MUST use the smallest design that satisfies documented behavior.
New dependencies, generalized abstractions, callbacks with non-local effects,
and data migrations MUST have a concrete reason recorded in the plan or review.
Features MUST be delivered as focused vertical slices with explicit acceptance
criteria. Rationale: a personal finance application benefits more from reliable,
understandable code than speculative flexibility.

## Technical Constraints

The application MUST remain compatible with Ruby on Rails 8.1, PostgreSQL, and
the repository's configured test and asset toolchain unless a constitution
amendment or feature plan explicitly changes that baseline. Database changes
MUST use reversible migrations where practical and MUST preserve existing user
financial data. Monetary values MUST use precise database-backed numeric handling;
floating-point arithmetic MUST NOT be used for persisted money calculations.

Authentication and authorization MUST protect user-owned financial data. Logs,
fixtures, tests, and error messages MUST NOT expose passwords, tokens, or other
secrets. Security-sensitive changes MUST be checked with the repository's
security tooling or an equivalent documented review.

## Development Workflow

Feature work MUST follow the repository's Spec Kit sequence when the change is
more than a local defect fix: specify, clarify when needed, plan, generate tasks,
then implement. Each plan MUST identify affected domain rules, data changes,
user-visible behavior, and verification steps. Pull requests MUST explain the
behavior changed, tests run, migration impact, and any known follow-up.

Before merge, applicable checks MUST pass, including the Rails test suite,
security analysis for security-sensitive changes, and Herb linting for modified
HTML/ERB views. Reviewers MUST reject changes that violate financial correctness,
data safety, or required test coverage unless an explicit exception is recorded
with owner and follow-up.

## Governance

This constitution defines non-negotiable project quality rules. Where another
practice conflicts with it, this document takes precedence unless amended.

Amendments MUST be proposed as a change to this file, include a Sync Impact
Report, explain affected principles and migration needs, and receive project-owner
approval. The amendment MUST update the version and last-amended date. Changes
that remove or redefine a principle are MAJOR; additions or material expansions
are MINOR; clarifications and non-semantic corrections are PATCH changes.

Every feature plan and pull-request review MUST check applicable principles.
Exceptions MUST state the violated rule, reason, risk, approver, and expiration
or follow-up condition. The constitution MUST be reviewed whenever the technology
baseline, data model, security model, or development workflow materially changes.

**Version**: 1.1.0 | **Ratified**: TODO(RATIFICATION_DATE): confirm original adoption date | **Last Amended**: 2026-08-12
