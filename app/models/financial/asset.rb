# Temporary compatibility adapter for callers not yet using Financial::Account.assets.
class Financial::Asset < Financial::Account
  default_scope { where(account_group: "asset") }

  before_validation { self.account_group = "asset" }
end
