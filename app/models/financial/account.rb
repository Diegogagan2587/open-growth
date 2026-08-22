# frozen_string_literal: true

class Financial::Account < ApplicationRecord
  self.table_name = "financial_accounts"
  self.inheritance_column = :_type_disabled
  ACCOUNT_GROUPS = %w[asset liability].freeze
  ACCOUNT_TYPES = %w[debit checking savings credit_card personal_credit].freeze
  STATUSES = %w[active closed archived].freeze
  belongs_to :account, class_name: "::Account"
  has_many :financial_entries, class_name: "Financial::Entry", foreign_key: :financial_account_id,
    dependent: :restrict_with_error, inverse_of: :financial_account
  scope :for_account, ->(account) { where(account: account) }
  scope :assets, -> { where(account_group: "asset") }
  scope :liabilities, -> { where(account_group: "liability") }
  scope :active, -> { where(status: "active") }
  before_validation :set_account, on: :create
  validates :name, presence: true, uniqueness: { scope: [ :account_id, :account_group ] }
  validates :account_group, presence: true, inclusion: { in: ACCOUNT_GROUPS }
  validates :account_type, presence: true, inclusion: { in: ACCOUNT_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :opening_balance, numericality: true
  validates :credit_limit, numericality: { greater_than: 0 }, allow_nil: true
  def asset?
    account_group == "asset"
  end

  def liability?
    account_group == "liability"
  end

  def current_balance
    if liability?
      entries = Financial::Entry.for_account(account).where(
        "financial_liability_id = :id OR counterparty_financial_liability_id = :id",
        id: id
      )
      opening_balance.to_d + entries.sum { |entry| entry.liability_delta_for(id) }
    else
      entries = Financial::Entry.for_account(account).where(
        "financial_account_id = :id OR counterparty_financial_account_id = :id",
        id: id
      )
      opening_balance.to_d + entries.sum { |entry| entry.account_delta_for(id) }
    end
  end

  def archived?
    status == "archived"
  end

  def liability_type
    account_type
  end

  def liability_type=(value)
    self.account_type = value
  end

  private

  def set_account
    self.account ||= Current.account if Current.account
  end
end
