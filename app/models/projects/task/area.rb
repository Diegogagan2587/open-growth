# frozen_string_literal: true

class Projects::Task::Area < ApplicationRecord
  self.table_name = "task_areas"

  belongs_to :account
  has_many :recurring_tasks,
    class_name: "Projects::Task::Recurring",
    foreign_key: :task_area_id,
    inverse_of: :task_area,
    dependent: :nullify

  validates :name, presence: true
  validates :name, uniqueness: { scope: :account_id }

  before_validation :set_account, on: :create

  scope :for_account, ->(account) { where(account: account) }

  # Preserve the existing form parameter names and submit labels.
  def self.model_name
    @model_name ||= ActiveModel::Name.new(self, nil, "TaskArea")
  end

  private

  def set_account
    self.account ||= Current.account if Current.account
  end
end
