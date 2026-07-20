module Financial
  module Loans
    class GenerateInstallmentsService
      Result = Struct.new(:success?, :error_message, :installments, keyword_init: true)

      PERIODS_PER_YEAR = { "weekly" => 52.to_d, "biweekly" => 26.to_d, "quincenal" => (365.to_d / 15), "monthly" => 12.to_d }.freeze

      def self.call(loan:, start_date:)
        new(loan:, start_date:).call
      end

      def initialize(loan:, start_date:)
        @loan = loan
        @start_date = start_date.to_date
      end

      def call
        unless loan.number_of_payments.to_i.positive? && PERIODS_PER_YEAR.key?(loan.payment_frequency)
          return Result.new(success?: false, error_message: "Number of payments and payment frequency are required", installments: [])
        end

        installments = ActiveRecord::Base.transaction do
          loan.installments.where(planned_transaction_id: nil, payment_entry_id: nil).delete_all
          build_installments
        end
        Result.new(success?: true, installments: installments)
      rescue ActiveRecord::RecordInvalid, ArgumentError => error
        Result.new(success?: false, error_message: error.message, installments: [])
      end

      private

      attr_reader :loan, :start_date

      def build_installments
        remaining = loan.principal_amount.to_d
        rate = (loan.interest_rate.to_d / 100) / PERIODS_PER_YEAR.fetch(loan.payment_frequency, 12.to_d)
        payment = loan.payment_amount.presence&.to_d || amortized_payment(remaining, rate, loan.number_of_payments)

        (1..loan.number_of_payments).map do |number|
          interest = (remaining * rate).round(2)
          principal = number == loan.number_of_payments ? remaining : [ payment - interest, remaining ].min.round(2)
          amount = (principal + interest).round(2)
          installment = loan.installments.create!(
            account: loan.account,
            installment_number: number,
            due_date: due_date_for(number),
            expected_amount: amount,
            expected_principal: principal,
            expected_interest: interest,
            resolution: "scheduled"
          )
          remaining = (remaining - principal).round(2)
          installment
        end
      end

      def amortized_payment(principal, rate, periods)
        return (principal / periods).round(2) if rate.zero?

        (principal * rate / (1 - (1 + rate)**(-periods))).round(2)
      end

      def due_date_for(number)
        case loan.payment_frequency
        when "weekly" then start_date + number.weeks
        when "biweekly" then start_date + (number * 2).weeks
        when "quincenal" then start_date + (number * 15).days
        else start_date.advance(months: number)
        end
      end
    end
  end
end
