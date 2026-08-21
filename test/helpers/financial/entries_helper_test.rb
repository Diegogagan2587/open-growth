require "test_helper"

class Financial::EntriesHelperTest < ActionView::TestCase
  test "uses transaction semantics for amount presentation" do
    funding = Financial::Transaction.new(transaction_type: "refund")
    adjustment = Financial::Transaction.new(transaction_type: "adjustment")
    expense = Financial::Transaction.new(transaction_type: "expense")

    assert_equal "+", financial_entry_amount_prefix(funding)
    assert_equal "text-success", financial_entry_amount_class(adjustment)
    assert_equal "−", financial_entry_amount_prefix(expense)
    assert_equal "text-danger", financial_entry_amount_class(expense)
  end
end
