module PlannedExpenses
  class ExecuteService
    Result = Struct.new(:success?, :error_message, :planned_expense, :expense, :entry, keyword_init: true)

    def self.call(...)
      new(...).call
    end

    def initialize(planned_expense:, entry_date: nil, target_status: nil)
      @planned_expense = planned_expense
      @entry_date = entry_date
      @target_status = target_status
    end

    def call
      return failure("Planned expense is required") if planned_expense.blank?

      ActiveRecord::Base.transaction do
        expense = build_or_update_expense_if_needed
        entry = build_or_update_financial_entry!(expense: expense)

        planned_expense.update!(status: status_after_execution) unless planned_expense.status == status_after_execution

        Result.new(success?: true, planned_expense: planned_expense, expense: expense, entry: entry)
      end
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.to_sentence)
    end

    private

    attr_reader :planned_expense, :entry_date, :target_status

    def expense_attributes
      {
        date: entry_date,
        amount: planned_expense.amount,
        description: planned_expense.description,
        category: planned_expense.category,
        budget_period: planned_expense.income_event.budget_period,
        income_event: planned_expense.income_event,
        planned_expense: planned_expense,
        account: planned_expense.account,
        financial_account: planned_expense.financial_account,
        financial_liability: planned_expense.financial_liability
      }
    end

    def build_or_update_expense_if_needed
      return nil if transaction_routing?
      return nil if planned_expense.income_event.budget_period.blank?

      expense = Expense.find_by(planned_expense_id: planned_expense.id) || planned_expense.expense || Expense.new
      expense.assign_attributes(expense_attributes)
      expense.save!
      expense
    end

    def build_or_update_financial_entry!(expense:)
      entry = Financial::Entry.find_by(planned_expense_id: planned_expense.id) || planned_expense.financial_entry || Financial::Entry.new
      entry.account = planned_expense.account
      entry.income_event = planned_expense.income_event
      entry.planned_expense = planned_expense
      entry.expense = expense if expense.present?
      entry.entry_date = entry_date
      entry.amount = planned_expense.amount
      entry.description = planned_expense.description

      if planned_expense.transfer?
        entry.entry_type = "transfer"
        entry.financial_account = planned_expense.financial_account
        entry.counterparty_financial_account = planned_expense.counterparty_financial_account
        entry.financial_liability = nil
        entry.counterparty_financial_liability = nil
      elsif planned_expense.debt_payment?
        entry.entry_type = "liability_payment"
        entry.financial_account = planned_expense.financial_account
        entry.financial_liability = planned_expense.financial_liability
        entry.counterparty_financial_account = nil
        entry.counterparty_financial_liability = nil
      elsif planned_expense.financial_liability.present?
        entry.entry_type = "liability_charge"
        entry.financial_account = nil
        entry.financial_liability = planned_expense.financial_liability
        entry.counterparty_financial_account = nil
        entry.counterparty_financial_liability = nil
      else
        entry.entry_type = "outflow"
        entry.financial_account = planned_expense.financial_account
        entry.financial_liability = nil
        entry.counterparty_financial_account = nil
        entry.counterparty_financial_liability = nil
      end

      entry.save!
      entry
    end

    def transaction_routing?
      planned_expense.transfer? || planned_expense.debt_payment?
    end

    def status_after_execution
      return target_status if PlannedExpense.final_status?(target_status)
      return "transferred" if planned_expense.transfer?
      return "paid" if planned_expense.debt_payment?

      "paid"
    end

    def resolved_entry_date
      return entry_date if entry_date.present?
      return planned_expense.applied_on if planned_expense.applied_on.present?
      return planned_expense.due_date if planned_expense.due_date.present? && planned_expense.final_status?

      Date.current
    end

    def failure(message)
      Result.new(success?: false, error_message: message, planned_expense: planned_expense)
    end
  end
end
