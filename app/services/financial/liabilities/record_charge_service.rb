module Financial::Liabilities
  class RecordChargeService
    Result = Struct.new(:success?, :error_message, :entry, keyword_init: true)

    def self.call(...)
      new(...).call
    end

    def initialize(liability:, amount:, description:, entry_date:, category_id:, budget_period_id:, income_event_id: nil)
      @liability = liability
      @amount = amount
      @description = description
      @entry_date = entry_date
      @category_id = category_id
      @budget_period_id = budget_period_id
      @income_event_id = income_event_id
    end

    def call
      return failure("Liability is required") if liability.blank?
      return failure("Amount must be greater than 0") unless amount.to_d.positive?
      return failure("Description is required") if description.blank?
      return failure("Entry date is required") if entry_date.blank?
      return failure("Category is required") if category.blank?
      return failure("Budget period is required") if budget_period.blank?

      created_entry = Financial::Transaction.create!(
        account: liability.account,
        source_account: liability,
        plan: plan,
        category: category,
        budget_period: budget_period,
        transaction_date: entry_date,
        amount: amount,
        description: description
      )

      Result.new(success?: true, entry: created_entry)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.to_sentence)
    end

    private

    attr_reader :liability, :amount, :description, :entry_date, :category_id, :budget_period_id, :income_event_id

    def category
      @category ||= Category.for_account(liability.account).find_by(id: category_id)
    end

    def budget_period
      @budget_period ||= BudgetPeriod.for_account(liability.account).find_by(id: budget_period_id)
    end

    def plan
      return nil if income_event_id.blank?

      @plan ||= Financial::Plan.for_account(liability.account).find_by(id: income_event_id)
    end

    def failure(message)
      Result.new(success?: false, error_message: message)
    end
  end
end
