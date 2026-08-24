module Financial
  module Loans
    class GenerateInstallmentsService
      Result = Struct.new(:success?, :error_message, :installments, keyword_init: true)

      def self.call(loan:, start_date: nil, first_payment_date: nil)
        new(loan:, start_date:, first_payment_date:).call
      end

      def initialize(loan:, start_date: nil, first_payment_date: nil)
        @loan = loan
        @start_date = start_date&.to_date
        @first_payment_date = first_payment_date&.to_date
      end

      def call
        result = Financial::Loans::RegenerateSchedule.call(loan: loan, start_date: start_date, first_payment_date: first_payment_date)
        Result.new(success?: result.success?, error_message: result.error_message, installments: result.installments)
      end

      private

      attr_reader :loan, :start_date, :first_payment_date
    end
  end
end
