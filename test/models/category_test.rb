require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  test "cannot delete a category referenced by an actual entry" do
    account = Account.create!(name: "Category Tenant")
    Current.account = account
    category = Category.create!(account: account, name: "Protected")
    asset = Financial::Asset.create!(
      account: account,
      name: "Main",
      account_type: "debit",
      status: "active",
      opening_balance: 0
    )
    entry = Financial::Entry.create!(
      account: account,
      category: category,
      financial_account: asset,
      entry_type: "outflow",
      entry_date: Date.current,
      amount: 10,
      description: "Purchase"
    )

    assert_not category.destroy
    assert Category.exists?(category.id)
    assert Financial::Entry.exists?(entry.id)
  ensure
    Current.account = nil
  end
end
