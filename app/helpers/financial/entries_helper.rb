module Financial::EntriesHelper
  def financial_entry_amount_prefix(entry)
    return "+" if entry.entry_type.in?(%w[inflow loan_disbursement adjustment])
    return "−" if entry.entry_type.in?(%w[outflow liability_charge liability_payment])

    ""
  end

  def financial_entry_amount_class(entry)
    return "text-success" if entry.entry_type.in?(%w[inflow loan_disbursement adjustment])
    return "text-danger" if entry.entry_type.in?(%w[outflow liability_charge liability_payment])

    "text-foreground"
  end
end
