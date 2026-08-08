# Temporary compatibility adapter for callers not yet using Financial::Account.liabilities.
class Financial::Liability < Financial::Account
  default_scope { where(account_group: "liability") }

  before_validation { self.account_group = "liability" }

  def liability_type
    account_type
  end

  def liability_type=(value)
    self.account_type = value
  end
end
