module Financial
  module FundingSources
    class ReceiveService
      def self.call(funding_source:, amount: nil, entry_date: nil, description: nil)
        Receipt.create(
          funding_source: funding_source,
          amount: amount,
          transaction_date: entry_date,
          description: description
        )
      end
    end
  end
end
