module Financial
  module FundingSources
    class ReceiveService
      Result = Struct.new(:success?, :error_message, :entry, keyword_init: true)

      def self.call(...)
        new(...).call
      end

      def initialize(funding_source:, amount: nil, entry_date: nil, description: nil)
        @funding_source = funding_source
        @amount = amount
        @entry_date = entry_date
        @description = description
      end

      def call
        return failure("Funding source is required") if funding_source.blank?

        entry = nil
        funding_source.with_lock do
          entry = funding_source.receipt_entry || build_entry
          entry.save!
          funding_source.update!(resolution: resolution_for(entry))
        end
        Result.new(success?: true, entry: entry)
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
        existing = funding_source&.reload&.receipt_entry
        return Result.new(success?: true, entry: existing) if existing

        failure(error.message)
      end

      private

      attr_reader :funding_source, :amount, :entry_date, :description

      def build_entry
        Financial::Entry.new(
          account: funding_source.account,
          funding_source: funding_source,
          income_event: funding_source.financial_plan,
          entry_type: "inflow",
          entry_date: entry_date.presence || funding_source.expected_date,
          amount: amount.presence || funding_source.expected_amount,
          description: description.presence || funding_source.description,
          financial_account: funding_source.expected_destination_asset,
          counterparty_financial_liability: funding_source.expected_destination_liability
        )
      end

      def resolution_for(entry)
        if entry.amount == funding_source.expected_amount && entry.entry_date == funding_source.expected_date
          "received"
        else
          "closed_with_variance"
        end
      end

      def failure(message)
        Result.new(success?: false, error_message: message)
      end
    end
  end
end
