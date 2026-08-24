class Financial::Loan::Installment < ApplicationRecord
  self.table_name = "financial_loan_installments"

  RESOLUTIONS = %w[scheduled paid skipped cancelled disputed].freeze

  belongs_to :account, class_name: "::Account"
  belongs_to :financial_loan, class_name: "Financial::Loan", inverse_of: :installments
  belongs_to :planned_transaction, class_name: "Financial::PlannedTransaction", optional: true
  belongs_to :payment_entry, class_name: "Financial::Entry", optional: true
  belongs_to :interest_entry, class_name: "Financial::Entry", optional: true

  validates :installment_number, numericality: { only_integer: true, greater_than: 0 }, uniqueness: { scope: :financial_loan_id }
  validates :due_date, presence: true
  validates :expected_amount, numericality: { greater_than: 0 }
  validates :expected_principal, :expected_interest, numericality: { greater_than_or_equal_to: 0 }
  validates :resolution, inclusion: { in: RESOLUTIONS }
end
