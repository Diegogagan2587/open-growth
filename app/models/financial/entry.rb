class Financial::Entry < ApplicationRecord
  self.table_name = "financial_entries"

  ENTRY_TYPES = %w[inflow outflow transfer liability_charge liability_payment loan_disbursement adjustment].freeze

  belongs_to :account, class_name: "::Account"
  belongs_to :category, optional: true
  belongs_to :budget_period, optional: true
  belongs_to :financial_account, class_name: "Financial::Asset", optional: true
  belongs_to :counterparty_financial_account, class_name: "Financial::Asset", optional: true
  belongs_to :financial_liability, class_name: "Financial::Liability", optional: true
  belongs_to :counterparty_financial_liability, class_name: "Financial::Liability", optional: true
  belongs_to :planned_expense, optional: true
  belongs_to :expense, optional: true
  belongs_to :income_event, optional: true

  before_validation :set_account, on: :create

  scope :for_account, ->(account) { where(account: account) }
  scope :by_date, -> { order(entry_date: :desc, created_at: :desc) }

  validates :entry_type, presence: true, inclusion: { in: ENTRY_TYPES }
  validates :entry_date, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :description, presence: true
  validates :category, presence: true, if: :classification_required?
  validates :budget_period, presence: true, if: :classification_required?

  validate :required_links_by_type
  validate :associations_belong_to_same_account

  def account_delta
    case entry_type
    when "inflow", "loan_disbursement"
      amount.to_d
    when "outflow", "liability_payment", "transfer"
      -amount.to_d
    when "adjustment"
      amount.to_d
    else
      0.to_d
    end
  end

  def classification_required?
    entry_type.in?(%w[outflow liability_charge])
  end

  def source_selection
    return "asset:#{financial_account_id}" if financial_account_id.present?
    return "liability:#{financial_liability_id}" if financial_liability_id.present?

    nil
  end

  def destination_selection
    return "asset:#{counterparty_financial_account_id}" if counterparty_financial_account_id.present?
    return "liability:#{financial_liability_id}" if entry_type == "liability_payment" && financial_liability_id.present?

    nil
  end

  def account_delta_for(financial_account_id)
    if entry_type == "transfer"
      return -amount.to_d if self.financial_account_id == financial_account_id
      return amount.to_d if counterparty_financial_account_id == financial_account_id

      return 0.to_d
    end

    if entry_type == "loan_disbursement"
      return amount.to_d if self.financial_account_id == financial_account_id
      return 0.to_d
    end

    return 0.to_d unless self.financial_account_id == financial_account_id

    account_delta
  end

  def liability_delta
    case entry_type
    when "liability_charge", "loan_disbursement"
      amount.to_d
    when "liability_payment"
      -amount.to_d
    else
      0.to_d
    end
  end

  def liability_delta_for(liability_id)
    if entry_type == "inflow"
      return -amount.to_d if counterparty_financial_liability_id == liability_id
      return 0.to_d
    end

    if entry_type == "loan_disbursement"
      return amount.to_d if financial_liability_id == liability_id
      return -amount.to_d if counterparty_financial_liability_id == liability_id
      return 0.to_d
    end

    return 0.to_d unless financial_liability_id == liability_id

    liability_delta
  end

  private

  def set_account
    self.account ||= Current.account if Current.account
  end

  def required_links_by_type
    case entry_type
    when "inflow"
      if financial_account.blank? && counterparty_financial_liability.blank?
        errors.add(:base, "inflow requires an asset or liability destination")
      end
      if financial_account.present? && counterparty_financial_liability.present?
        errors.add(:base, "inflow can have only one destination")
      end
    when "outflow", "adjustment"
      errors.add(:financial_account, "must be selected") if financial_account.blank?
    when "transfer"
      errors.add(:financial_account, "must be selected") if financial_account.blank?
      errors.add(:counterparty_financial_account, "must be selected") if counterparty_financial_account.blank?
      if financial_account_id.present? && counterparty_financial_account_id.present? && financial_account_id == counterparty_financial_account_id
        errors.add(:counterparty_financial_account, "must be different from source account")
      end
    when "liability_charge"
      errors.add(:financial_liability, "must be selected") if financial_liability.blank?
    when "liability_payment"
      errors.add(:financial_liability, "must be selected") if financial_liability.blank?
      if financial_account.blank? && income_event.blank?
        errors.add(:financial_account, "must be selected")
      end
    when "loan_disbursement"
      errors.add(:financial_liability, "must be selected") if financial_liability.blank?
      if financial_account.blank? && counterparty_financial_liability.blank?
        errors.add(:base, "loan disbursement requires an asset or liability destination")
      end
      if financial_account.present? && counterparty_financial_liability.present?
        errors.add(:base, "loan disbursement can have only one destination")
      end
    end
  end

  def associations_belong_to_same_account
    return if account.blank?

    if financial_account.present? && financial_account.account_id != account_id
      errors.add(:financial_account, "must belong to the current account")
    end

    if counterparty_financial_account.present? && counterparty_financial_account.account_id != account_id
      errors.add(:counterparty_financial_account, "must belong to the current account")
    end

    if financial_liability.present? && financial_liability.account_id != account_id
      errors.add(:financial_liability, "must belong to the current account")
    end

    if counterparty_financial_liability.present? && counterparty_financial_liability.account_id != account_id
      errors.add(:counterparty_financial_liability, "must belong to the current account")
    end

    if planned_expense.present? && planned_expense.account_id != account_id
      errors.add(:planned_expense, "must belong to the current account")
    end

    if expense.present? && expense.account_id != account_id
      errors.add(:expense, "must belong to the current account")
    end

    if income_event.present? && income_event.account_id != account_id
      errors.add(:income_event, "must belong to the current account")
    end
  end
end
