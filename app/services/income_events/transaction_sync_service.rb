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

      source.update!(expected_destination_account: destination)
      Financial::FundingSources::Receipt.create(
        funding_source: source,
        amount: income_event.received_amount || income_event.expected_amount,
        transaction_date: income_event.received_date || income_event.expected_date,
        description: income_event.description
      )
    end
  end
end
