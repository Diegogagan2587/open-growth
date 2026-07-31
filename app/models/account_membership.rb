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

  def ai_reports_available?
    Ai::Configuration.current.reports_enabled? && account.ai_reports_enabled? && ai_reports_enabled?
  end

  def ai_reports_requests_used(at: Time.current)
    reporting_usage_events.counted.during(at.beginning_of_month..at.end_of_month).count
  end

  def ai_reports_requests_remaining(at: Time.current)
    [ ai_reports_monthly_request_limit - ai_reports_requests_used(at: at), 0 ].max
  end

  private

  def ai_reports_limit_within_system_maximum
    return if ai_reports_monthly_request_limit.blank?
    return if ai_reports_monthly_request_limit <= Ai::Configuration.current.maximum_monthly_request_limit

    errors.add(:ai_reports_monthly_request_limit, "exceeds the system maximum")
  end
end
