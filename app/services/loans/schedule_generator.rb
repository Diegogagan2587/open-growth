  # frozen_string_literal: true

  class Loans::ScheduleGenerator
    PERIODS_PER_YEAR = {
      "weekly" => 52.0,
      "biweekly" => 26.0,
      "quincenal" => (365.0 / 15.0),
      "quicenal" => (365.0 / 15.0),
      "monthly" => 12.0
    }.freeze

    def self.call(loan, preserve_paid: true)
      new(loan, preserve_paid:).call
    end

    def self.annual_rate_from_payment(principal:, payment_amount:, number_of_payments:, payment_frequency:)
      Financial::Loans::RepaymentTerms.new(
        principal: principal,
        number_of_payments: number_of_payments,
        payment_frequency: payment_frequency,
        repayment_basis: "payment_amounts",
        regular_payment: payment_amount
      ).annual_rate
    end

    def initialize(loan, preserve_paid: true)
      @loan = loan
      @preserve_paid = preserve_paid
    end

    def call
      return [] unless loan.loan?
      return [] unless loan.loan_amount.present? && loan.number_of_payments.present? && loan.payment_frequency.present?

      ActiveRecord::Base.transaction do
        paid_rows = preserve_paid ? loan.loan_payment_schedules.paid.ordered.to_a : []
        loan.loan_payment_schedules.where.not(id: paid_rows.map(&:id)).delete_all

        generate_rows(paid_rows)
      end
    end

    private

    attr_reader :loan, :preserve_paid

    def generate_rows(paid_rows)
      rows = []
      start_index = paid_rows.size + 1
      remaining_principal = [ loan.loan_amount.to_d - paid_rows.sum { |row| row.principal_amount.to_d }, 0 ].max
      periodic_rate = periodic_interest_rate
      fixed_payment_mode = loan.payment_amount.present?
      fixed_payment_amount = loan.payment_amount.to_d.round(2)

      (start_index..loan.number_of_payments).each do |installment_number|
        break if remaining_principal <= 0 && !fixed_payment_mode

        due_date = due_date_for(installment_number)
        installments_left = loan.number_of_payments - installment_number + 1
        interest_amount = (remaining_principal * periodic_rate).round(2)

        principal_amount = if installment_number == loan.number_of_payments
          remaining_principal
        elsif fixed_payment_mode
          calculated_principal = (fixed_payment_amount - interest_amount).round(2)
          [ calculated_principal, remaining_principal ].min
        else
          payment_amount = payment_amount_for(remaining_principal, installments_left)
          (payment_amount - interest_amount).round(2)
        end
        amount = if installment_number == loan.number_of_payments
          (principal_amount + interest_amount).round(2)
        elsif fixed_payment_mode
          fixed_payment_amount
        else
          (principal_amount + interest_amount).round(2)
        end

        rows << loan.loan_payment_schedules.create!(
          account: loan.account,
          due_date: due_date,
          installment_number: installment_number,
          amount: amount,
          principal_amount: principal_amount,
          interest_amount: interest_amount,
          status: "scheduled"
        )

        remaining_principal = (remaining_principal - principal_amount).round(2)
      end

      rows
    end

    def payment_amount_for(principal, periods)
      if loan.payment_amount.present?
        loan.payment_amount.to_d
      else
        amortized_payment(principal, periods)
      end
    end

    def amortized_payment(principal, periods)
      rate = periodic_interest_rate

      return (principal / periods).round(2) if rate.zero?

      numerator = principal * rate
      denominator = 1 - (1 + rate)**(-periods)
      (numerator / denominator).round(2)
    end

    def periodic_interest_rate
      annual_rate = loan.interest_rate.to_d / 100
      annual_rate / periods_per_year
    end

    def periods_per_year
      PERIODS_PER_YEAR.fetch(loan.payment_frequency) { 12.0 }
    end

    def due_date_for(installment_number)
      offset = installment_number
      case loan.payment_frequency
      when "weekly"
        loan.expected_date + offset.weeks
      when "biweekly"
        loan.expected_date + (offset * 2).weeks
      when "quincenal", "quicenal"
        loan.expected_date + (offset * 15).days
      else
        loan.expected_date.advance(months: offset)
      end
    end
  end
