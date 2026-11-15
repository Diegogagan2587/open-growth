module Financial
  module Loans
    class ActivateService
      Result = Struct.new(:success?, :error_message, :entry, keyword_init: true)

      def self.call(loan:, plan:)
        entry = nil
        loan.with_lock do
          if loan.disbursement_fee_amount.positive? && loan.interest_category.blank?
            loan.errors.add(:interest_category, "must be selected to record the disbursement fee")
            raise ActiveRecord::RecordInvalid, loan
          end

          loan.lifecycle_status = "active"
          loan.save!
          source = loan.funding_sources.first_or_create!(
            account: loan.account,
            financial_plan: plan,
            description: loan.name,
            expected_amount: loan.net_disbursement_amount,
            expected_date: plan.planned_for,
            expected_destination_asset: loan.destination_asset,
            expected_destination_liability: loan.destination_liability,
            kind: "borrowed"
          )
          entry = source.receipt_entry || Financial::Entry.create!(
            account: loan.account,
            income_event: plan,
            funding_source: source,
            financial_loan: loan,
            entry_type: "loan_disbursement",
            entry_date: source.expected_date,
            amount: source.expected_amount,
            description: source.description,
            financial_liability: loan.liability,
            financial_account: loan.destination_asset,
            counterparty_financial_liability: loan.destination_liability
          )
          if loan.disbursement_fee_amount.positive? && loan.disbursement_fee_entry.blank?
            fee_entry = Financial::Entry.create!(
              account: loan.account,
              income_event: plan,
              financial_loan: loan,
              entry_type: "liability_charge",
              entry_date: source.expected_date,
              amount: loan.disbursement_fee_amount,
              description: "#{loan.name} withdrawal / transfer fee",
              financial_liability: loan.liability,
              category: loan.interest_category
            )
            loan.update!(disbursement_fee_entry: fee_entry)
          end
          source.update!(resolution: "received")
        end
        Result.new(success?: true, entry: entry)
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => error
        existing = loan&.reload&.entries&.find_by(entry_type: "loan_disbursement")
        return Result.new(success?: true, entry: existing) if existing

        Result.new(success?: false, error_message: error.message)
      end
    end
  end
end
