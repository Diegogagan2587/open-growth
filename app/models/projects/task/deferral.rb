# frozen_string_literal: true

class Projects::Task::Deferral < ApplicationRecord
  self.table_name = "dashboard_task_deferrals"

  TASK_TYPES = [ Projects::Task::Recurring.polymorphic_name, Projects::Task.polymorphic_name ].freeze

  belongs_to :account
  belongs_to :user
  belongs_to :task, polymorphic: true

  validates :task_type, inclusion: { in: TASK_TYPES }
  validates :deferred_at, presence: true
  validates :task_id, uniqueness: { scope: [ :account_id, :user_id, :task_type ] }
  validate :task_belongs_to_account

  def self.defer!(task:, account:, user:)
    deferral = find_or_initialize_by(account:, user:, task:)
    deferral.update!(deferred_at: Time.current)
    deferral
  end

  private

  def task_belongs_to_account
    return if task.blank? || account.blank? || task.account_id == account_id

    errors.add(:task, "must belong to the selected account")
  end
end
