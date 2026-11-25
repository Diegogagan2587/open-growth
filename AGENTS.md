# Open Budget agent instructions

Maintain shared repository guidance here. Tool-specific instruction files should point here. See the [README](README.md) for setup and features, the [roadmap](VISION_AND_ROADMAP.md) for project direction, and the [constitution](.specify/memory/constitution.md) for binding project principles.

## Development and verification

- Open Budget uses Rails 8.1, PostgreSQL, ViewComponent 4, Tailwind CSS, and Hotwire. Check `Gemfile.lock` for the exact versions.
- Run `bin/dev` to start the web server, jobs, and Tailwind watcher. Use `bin/rails console` for inspection and `bin/rails db:migrate` for migrations. `bin/rails db:reset` recreates the configured database and discards its data.
- Run `bin/rails test` for the Rails suite or `bin/rails test test/models/income_event_test.rb` for a focused run. Run `bin/rails test:system` for system tests. See [CI](.github/workflows/ci.yml) for the configured checks.
- Run `bin/rubocop` for Ruby linting, `npm run herb:lint` for changed HTML/ERB views, and `bin/brakeman` for Rails security analysis. Run applicable checks before merge.
- Inspect relevant code, tests, fixtures, components, and dependencies before introducing a new pattern. Prefer Rails and the project’s existing solutions.

## Accounts and financial behavior

- An `Account` represents a household. Scope each account-owned query through `Current.account`, a scoped association, or `.for_account(account)`. Use `AccountScoping` to require a selected account in controllers and scope record lookups to enforce isolation. Pass the account explicitly to background jobs.
- Authentication uses a signed session ID cookie backed by a database `Session`. Use `require_authentication` and access request context through `Current.user` and `Current.account`.
- Give new account-owned models an `account_id` foreign key, validations, and appropriate associations and scopes. Choose `dependent: :destroy` or `:nullify` based on ownership and retention. Follow the `before_validation` account assignment pattern where a record derives its account from its parent or the request context.
- Use named scopes for common queries, for example `IncomeEvent.for_account(Current.account).pending.by_date`. Prefer Active Record scopes for everyday queries.
- Keep planned spending and actual spending distinct. The income-event flow connects `IncomeEvent`, `PlannedExpense`, and `Expense` and uses `BudgetPeriod` and `Category` for budgeting and classification. Check its existing execution path, previous-balance calculation, and expected, actual, and remaining spending when changing that flow. Read `Financial::Plan` and `config/routes.rb` for the current `/finance` workflow. Other domains include shopping and inventory, projects and tasks, and household docs.
- Put financial invariants and atomic multi-write operations in the owning domain object. Use precise numeric handling for persisted money, preserve existing financial data, and verify boundary and migration cases.

## Rails code and UI

- Keep controllers focused on request handling and delegate business behavior to domain models or explicit domain objects. Keep background jobs focused on invoking domain behavior.
- Prefer RESTful resources. Consider modeling a separate resource before adding a custom member action. Consult `config/routes.rb` for existing patterns, including finance, nested planned expenses, `/task/areas`, and `/projects`.
- Prefer compact constant-path declarations for namespaced classes and modules, such as `class Financial::BalanceCalculator::SumService`. Use role-appropriate suffixes such as `Service`, `Query`, `Controller`, `Component`, and `Mailer` for those roles.
- Build reusable UI with [ViewComponents](app/components/) and Tailwind. Use semantic design tokens and compose existing components. Use Tailwind classes for layout and styling and preserve semantic markup, keyboard access, readable contrast, and responsive behavior.
- For Rails UI work, use the [Rails UI component porter skill](.agents/skills/rails-ui-component-porter/SKILL.md). If no suitable component exists, inspect the closest official shadcn/ui pattern and adapt it to the project’s Rails and Hotwire stack.

## Tests and feature workflow

- Use test-first development for behavior changes. Add a focused Minitest test at the appropriate boundary, confirm the expected failure, implement the change, then rerun the test. Record the reason if an automated test cannot reasonably drive the change.
- Rails tests are configured to run in parallel and load `test/fixtures/`. Check existing fixtures before adding records. Use `sign_in_as(user, account)` from [test/test_helper.rb](test/test_helper.rb) for authenticated integration tests and set `Current.account` in tests that need account context outside a request. Cover account isolation and relevant edge cases, especially income-event balances.
- For feature work beyond a local defect fix, follow Spec Kit through [specification](.agents/skills/speckit-specify/SKILL.md), [clarification when needed](.agents/skills/speckit-clarify/SKILL.md), [planning](.agents/skills/speckit-plan/SKILL.md), [task generation](.agents/skills/speckit-tasks/SKILL.md), and [implementation](.agents/skills/speckit-implement/SKILL.md). Scope the work into verifiable vertical slices. The [project skill catalog](.agents/skills/) contains the other Spec Kit workflows.
