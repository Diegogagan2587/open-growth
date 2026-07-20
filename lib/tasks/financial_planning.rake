namespace :financial_planning do
  desc "Report planning/accounting inconsistencies without changing data"
  task audit: :environment do
    FinancialPlanningAudit.call.each do |name, ids|
      puts "#{name}=#{ids.size} ids=#{ids.join(',')}"
    end
  end
end
