module Financial::Liabilities
  class RecordPaymentService
    Result = Struct.new(:success?, :error_message, :entry, keyword_init: true)

    def self.call(...)
      new(...).call
    end

    def initialize(liability:, source_account:, amount:, description:, entry_date:, income_event: nil)
      @liability = liability
      @source_account = source_account
      @amount = amount
      @description = description
      @entry_date = entry_date
      @income_event = income_event
    end

    def call
      return failure("Liability is required") if liability.blank?
      return failure("Source account is required") if source_account.blank?
      return failure("Amount must be greater than 0") unless amount.to_d.positive?
      return failure("Entry date is required") if entry_date.blank?
      return failure("Description is required") if description.blank?
      return failure("Source account must belong to the same household") unless source_account.account_id == liability.account_id
      return failure("Payment amount cannot exceed outstanding liability") if amount.to_d > liability.current_balance.to_d

      created_entry = Financial::Transaction.create!(
        account: liability.account,
        source_account: source_account,
        destination_account: liability,
        plan: income_event,
        transaction_date: entry_date,
        amount: amount,
        description: description
      )

      Result.new(success?: true, entry: created_entry)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.to_sentence)
    end

    private

    attr_reader :liability, :source_account, :amount, :description, :entry_date, :income_event

    def failure(message)
      Result.new(success?: false, error_message: message)
    end
  end
end
