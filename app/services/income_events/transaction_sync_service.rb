module IncomeEvents
  class TransactionSyncService
    def self.call(...)
      new(...).call
    end

    def initialize(income_event)
      @income_event = income_event
    end

    def call
      return if income_event.loan?

      return unless income_event.status.in?(%w[received applied]) && destination

      create_receipt_once!
    end

    private

    attr_reader :income_event

    def destination
      income_event.regular_income_destination_asset || income_event.regular_income_destination_liability
    end

    def create_receipt_once!
      plan = Financial::Plan.find(income_event.id)
      source = plan.funding_sources.find_by(legacy_income_event_id: income_event.id)
      return unless source
      return if source.receipt_transaction

      entry = Financial::Entry.for_account(income_event.account)
        .find_or_initialize_by(
          income_event: income_event,
          entry_type: "inflow",
          expense_id: nil,
          planned_expense_id: nil
        )

      entry.assign_attributes(
        account: income_event.account,
        entry_date: income_event.received_date || income_event.expected_date,
        amount: income_event.received_amount || income_event.expected_amount,
        description: income_event.description,
        financial_account: income_event.regular_income_destination_asset,
        financial_liability: nil,
        counterparty_financial_liability: income_event.regular_income_destination_liability
      )

      entry.save!
    end
  end
end
