module Financial
  module Plans
    class CloseService
      Result = Struct.new(:success?, :error_message, :plan, keyword_init: true)

      def self.call(plan:)
        plan.with_lock do
          ending_balance = Financial::PlanActuals.for(plan).ending_balance
          plan.update!(
            lifecycle_status: "closed",
            closed_at: Time.current,
            actual_ending_balance_at_close: ending_balance
          )
        end
        Result.new(success?: true, plan: plan)
      rescue ActiveRecord::RecordInvalid => error
        Result.new(success?: false, error_message: error.message, plan: plan)
      end
    end
  end
end
