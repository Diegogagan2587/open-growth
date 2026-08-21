# Temporary compatibility adapter. New code uses Financial::Transaction.
class Financial::Entry < Financial::Transaction
  module LegacyRelation
    def where(*arguments)
      if arguments.first.is_a?(Hash) && arguments.first.key?(:entry_type)
        attributes = arguments.first.dup
        original = attributes.delete(:entry_type)
        mapped = Array(original).map { |value| Financial::Entry::LEGACY_TYPES.fetch(value.to_s, value) }
        attributes[:transaction_type] = original.is_a?(Array) ? mapped : mapped.first
        arguments[0] = attributes
      end
      super
    end
  end

  LEGACY_TYPES = {
    "inflow" => "income",
    "outflow" => "expense",
    "liability_charge" => "expense",
    "liability_payment" => "debt_payment"
  }.freeze
  ENTRY_TYPES = %w[inflow outflow transfer liability_charge liability_payment loan_disbursement adjustment].freeze
  EXPENSE_ENTRY_TYPES = %w[outflow liability_charge].freeze

  alias_attribute :entry_type, :transaction_type
  alias_attribute :entry_date, :transaction_date

  validate :legacy_route_error_names

  def entry_type
    return "liability_charge" if transaction_type == "expense" && source_account&.liability?

    LEGACY_TYPES.key(transaction_type) || transaction_type
  end

  def entry_type=(value)
    self.transaction_type = LEGACY_TYPES.fetch(value.to_s, value)
  end

  def entry_date
    transaction_date
  end

  def entry_date=(value)
    self.transaction_date = value
  end

  alias_method :date, :entry_date
  alias_method :date=, :entry_date=

  def liability_delta_for(account_id)
    account_delta_for(account_id)
  end

  def net_asset_effect
    return 0.to_d if entry_type == "transfer"
    return amount.to_d if entry_type.in?(%w[inflow adjustment]) && financial_account
    return -amount.to_d if entry_type == "outflow" && financial_account

    super
  end

  def net_liability_effect
    return amount.to_d if entry_type == "liability_charge" && financial_liability
    return -amount.to_d if entry_type == "liability_payment" && financial_liability

    super
  end

  def self.where(*arguments)
    if arguments.first.is_a?(Hash) && arguments.first.key?(:entry_type)
      attributes = arguments.first.dup
      attributes[:transaction_type] = Array(attributes.delete(:entry_type)).map { |value| LEGACY_TYPES.fetch(value.to_s, value) }
      attributes[:transaction_type] = attributes[:transaction_type].first unless arguments.first[:entry_type].is_a?(Array)
      arguments[0] = attributes
    end
    super
  end

  def self.for_account(account)
    super.extending(LegacyRelation)
  end

  private

  def legacy_route_error_names
    case entry_type
    when "transfer"
      errors.add(:counterparty_financial_account, "must be selected") if destination_account.blank?
    when "liability_payment"
      errors.add(:financial_account, "must be selected") if source_account.blank?
      errors.add(:financial_liability, "must be selected") if destination_account.blank?
    when "loan_disbursement"
      errors.add(:financial_liability, "must be selected") if source_account.blank?
      errors.add(:base, "loan disbursement requires an asset or liability destination") if destination_account.blank?
    end
  end
end
