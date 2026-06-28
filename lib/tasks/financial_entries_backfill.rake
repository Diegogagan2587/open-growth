namespace :financial_entries do
  desc "Backfill financial_entries from expenses in an idempotent way"
  task backfill_from_expenses: :environment do
    result = Financial::Entries::ExpenseBackfillService.call

    puts "created=#{result.created} updated=#{result.updated} skipped=#{result.skipped}"
    if result.errors.any?
      puts "errors=#{result.errors.size}"
      result.errors.each { |error| puts error }
      abort("Backfill completed with errors")
    end
  end
end
