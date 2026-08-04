module Financial
  module Loans
    class GenerateInstallmentsService
      Result = Struct.new(:success?, :error_message, :installments, keyword_init: true)

      def self.call(loan:, start_date:)
        new(loan:, start_date:).call
      end

      def initialize(loan:, start_date:)
        @loan = loan
        @start_date = start_date.to_date
      end

      def call
        result = Financial::Loans::RegenerateSchedule.call(loan: loan, start_date: start_date)
        Result.new(success?: result.success?, error_message: result.error_message, installments: result.installments)
      end

      private

      attr_reader :loan, :start_date
    end
  end
end
