module Financial
  module Loans
    class ActivateService
      def self.call(loan:, plan:)
        Financial::Loan::Disbursement.create(loan: loan, plan: plan)
      end
    end
  end
end
