# frozen_string_literal: true

class RecurringTask < ApplicationRecord
  RECURRENCE_VALUES = %w[none once daily weekly biweekly monthly].freeze

  belongs_to :account
  belongs_to :task_area, optional: true
  has_many :dashboard_task_deferrals,
    as: :task,
    class_name: "Dashboard::TaskDeferral",
    dependent: :destroy

  validates :name, presence: true
  validates :recurrence, presence: true, inclusion: { in: RECURRENCE_VALUES }

  before_validation :set_account, on: :create

  scope :for_account, ->(account) { where(account: account) }
  scope :pending, -> { where.not(next_due_date: nil) }
  scope :overdue, -> { where("next_due_date < ?", Date.current) }
  scope :due_on_or_before, ->(date) { where("next_due_date <= ?", date) }
  scope :by_next_due, -> { order(Arel.sql("next_due_date IS NULL"), :next_due_date, :position, :created_at) }

  def mark_done!
    now = Time.current
    new_next_due = recurring? ? next_due_after(now) : nil
    with_lock do
      update!(last_done_at: now, next_due_date: new_next_due)
      dashboard_task_deferrals.delete_all
    end
  end

  def recurring?
    RECURRENCE_VALUES.excluding("none", "once").include?(recurrence)
  end

  def overdue?
    next_due_date.present? && next_due_date < Date.current
  end

  private

  def set_account
    self.account ||= Current.account if Current.account
  end

  def next_due_after(from_time)
    from = from_time.to_date
    case recurrence
    when "daily" then from + 1.day
    when "weekly" then from + 1.week
    when "biweekly" then from + 2.weeks
    when "monthly" then from + 1.month
    else from
    end
  end
end
