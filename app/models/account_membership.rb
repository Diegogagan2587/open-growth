class AccountMembership < ApplicationRecord
  belongs_to :user
  belongs_to :account

  validates :role, presence: true, inclusion: { in: %w[owner member] }
  validates :user_id, uniqueness: { scope: :account_id }

  scope :owners, -> { where(role: "owner") }
  scope :members, -> { where(role: "member") }

  has_many :reporting_conversations, class_name: "Reporting::Conversation", dependent: :destroy
  has_many :reporting_usage_events, class_name: "Reporting::UsageEvent", dependent: :nullify

  validates :ai_reports_monthly_request_limit, numericality: { only_integer: true, greater_than: 0 }
  validate :ai_reports_limit_within_system_maximum

  def owner?
    role == "owner"
  end
end
