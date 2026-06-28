module Loans
  class PlannedExpenseSyncService
    FINAL_STATUSES = %w[paid transferred spent].freeze

    def self.call(loan)
      new(loan).call
    end

    def initialize(loan)
      @loan = loan
    end

    def call
      return [] unless loan.loan?

      category = repayment_category
      return [] if category.blank?

      existing = loan.planned_expenses
        .includes(:category, :financial_account, :financial_liability, :counterparty_financial_account)
        .where.not(loan_installment_number: nil)
        .index_by(&:loan_installment_number)
      active_installments = loan.loan_payment_schedules.active.ordered
      active_numbers = active_installments.map(&:installment_number)

      ActiveRecord::Base.transaction do
        archive_missing_installments(existing, active_numbers)

        active_installments.map do |schedule|
          planned = existing[schedule.installment_number] || loan.planned_expenses.build(account: loan.account, loan_installment_number: schedule.installment_number)
          assign_attributes(planned, schedule, category)
          planned.save!
          planned
        end
      end
    end

    private

    attr_reader :loan

    def repayment_category
      @repayment_category ||= Category.for_account(loan.account).order(:id).first
    end

    def assign_attributes(planned, schedule, category)
      planned.category = planned.category || category
      planned.description = "Loan payment ##{schedule.installment_number} - #{loan.description}" if planned.description.blank?
      planned.amount = schedule.amount
      planned.notes ||= "Auto-generated from loan schedule"
      planned.origin_income_event = loan
      planned.due_date = schedule.due_date
      planned.status ||= "pending_to_pay"

      return if FINAL_STATUSES.include?(planned.status)

      planned.status = "pending_to_pay"
      planned.financial_account = loan.loan_disbursement_destination_asset
      planned.financial_liability = loan.loan_liability
    end

    def archive_missing_installments(existing, active_numbers)
      existing.each do |installment_number, planned|
        next if active_numbers.include?(installment_number)
        next if FINAL_STATUSES.include?(planned.status)

        planned.destroy!
      end
    end
  end
end
