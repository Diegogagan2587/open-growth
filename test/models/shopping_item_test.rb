require "test_helper"

class ShoppingItemTest < ActiveSupport::TestCase
  test "actual conversion creates a canonical financial entry without a legacy expense" do
    account = Account.create!(name: "Shopping Tenant")
    Current.account = account
    category = Category.create!(account: account, name: "Household")
    period = BudgetPeriod.create!(account: account, name: "July", start_date: Date.current.beginning_of_month, end_date: Date.current.end_of_month)
    asset = Financial::Asset.create!(account: account, name: "Checking", account_type: "checking", status: "active", opening_balance: 0)
    item = ShoppingItem.create!(account: account, category: category, name: "Soap", estimated_amount: 12, status: "pending", item_type: "one_time")

    assert_no_difference("Expense.count") do
      entry = item.convert_to_expense(period, financial_account: asset)
      assert_instance_of Financial::Entry, entry
      assert_equal "outflow", entry.entry_type
      assert_equal entry, item.reload.financial_entry
    end
  ensure
    Current.account = nil
  end
end
