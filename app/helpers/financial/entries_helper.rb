module Financial::EntriesHelper
  def financial_entry_amount_prefix(entry)
    return "+" if entry.funding? || entry.transaction_type == "adjustment"
    return "−" if entry.transaction_type.in?(%w[expense debt_payment])

    ""
  end

  def financial_entry_amount_class(entry)
    return "text-success" if entry.funding? || entry.transaction_type == "adjustment"
    return "text-danger" if entry.transaction_type.in?(%w[expense debt_payment])

    "text-foreground"
  end
end
