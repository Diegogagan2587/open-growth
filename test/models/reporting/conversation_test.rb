require "test_helper"

class Reporting::ConversationTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @membership = account_memberships(:one)
    @conversation = Reporting::Conversation.create!(
      account: @account,
      account_membership: @membership,
      title: "Reconciliation",
      date_from: Date.current.beginning_of_month,
      date_to: Date.current
    )
  end

  test "scope is immutable" do
    assert_not @conversation.update(date_from: 2.months.ago.to_date)
    assert_includes @conversation.errors[:base], "conversation scope cannot be changed"
  end

  test "deleting content retains usage metadata" do
    turn = @conversation.turns.create!(question: "What is missing?")
    event = Reporting::UsageEvent.create!(
      account: @account,
      user: @membership.user,
      account_membership: @membership,
      conversation: @conversation,
      turn: turn,
      model: "gpt-5.6-luna"
    )

    @conversation.destroy!

    assert event.reload
    assert_nil event.conversation_id
    assert_nil event.turn_id
  end

  test "keeps a cached turn count for conversation lists" do
    assert_difference -> { @conversation.reload.turns_count }, 1 do
      @conversation.turns.create!(question: "What changed?")
    end
  end
end
