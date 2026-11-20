# frozen_string_literal: true

class TaskArea < ApplicationRecord
  belongs_to :account
  has_many :recurring_tasks, dependent: :nullify

  validates :name, presence: true
  validates :name, uniqueness: { scope: :account_id }

  before_validation :set_account, on: :create

  scope :for_account, ->(account) { where(account: account) }

  private

  def set_account
    self.account ||= Current.account if Current.account
  end
end
