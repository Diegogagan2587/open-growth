class Financial::PlannedTransactionTemplate < ExpenseTemplate
  self.table_name = "expense_templates"

  alias_attribute :default_amount, :total_amount
end
