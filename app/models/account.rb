class Account < ApplicationRecord
  has_many :account_memberships, dependent: :destroy
  has_many :users, through: :account_memberships

  has_many :budget_periods, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :expenses, dependent: :destroy
  has_many :expense_templates, dependent: :destroy
  has_many :income_events, dependent: :destroy
  has_many :financial_plans, class_name: "Financial::Plan"
  has_many :financial_funding_sources, class_name: "Financial::FundingSource", dependent: :destroy
  has_many :financial_loans, class_name: "Financial::Loan", dependent: :destroy
  has_many :financial_accounts, class_name: "Financial::Account", dependent: :destroy
  has_many :financial_liabilities, class_name: "Financial::Liability", dependent: :destroy
  has_many :financial_entries, class_name: "Financial::Entry", dependent: :destroy
  has_many :planned_expenses, dependent: :destroy
  has_many :financial_planned_transactions, class_name: "Financial::PlannedTransaction"
  has_many :budget_line_items, dependent: :destroy
  has_many :shopping_items, dependent: :destroy
  has_many :inventory_items, dependent: :destroy
  has_many :task_areas, class_name: "Projects::Task::Area", dependent: :destroy
  has_many :recurring_tasks, class_name: "Projects::Task::Recurring", dependent: :destroy
  has_many :habits, dependent: :destroy
  has_many :habit_skills, class_name: "Habit::Skill", dependent: :destroy
  has_many :dashboard_task_deferrals, class_name: "Projects::Task::Deferral", dependent: :destroy
  has_many :career_companies, class_name: "Career::Company", dependent: :destroy
  has_many :career_job_applications, class_name: "Career::JobApplication", dependent: :destroy
  has_many :career_events, class_name: "Career::Event", dependent: :destroy
  has_one :career_profile, class_name: "Career::Profile", dependent: :destroy
  has_many :reporting_conversations, class_name: "Reporting::Conversation", dependent: :destroy
  has_many :reporting_usage_events, class_name: "Reporting::UsageEvent", dependent: :destroy

  validates :name, presence: true

  def owner
    account_memberships.owners.first&.user
  end
end
