class Financial::CategoryBudgets::Overview
  Row = Data.define(:budget, :allowance, :spent, :remaining)

  def self.for(account:, range_start:, range_end:)
    budgets = Financial::CategoryBudget.where(account: account).joins(:category).includes(:category).order("categories.name")
    actuals = Financial::Entry.where(account: account, entry_type: Financial::Entry::EXPENSE_ENTRY_TYPES,
      entry_date: range_start..range_end).group(:category_id).sum(:amount)
    budgets.map do |budget|
      allowance = budget.allowance_between(range_start, range_end)
      spent = actuals.fetch(budget.category_id, 0).to_d
      Row.new(budget, allowance, spent, allowance - spent)
    end
  end
end
