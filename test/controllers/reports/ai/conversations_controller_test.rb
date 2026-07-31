require "test_helper"

class Reports::Ai::ConversationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = accounts(:one)
    @membership = account_memberships(:one)
    sign_in_as(@user, @account)
  end

  test "disabled membership cannot create a conversation" do
    post reports_ai_conversations_path, params: {
      reporting_conversation: { title: "Blocked", date_from: Date.current.beginning_of_month, date_to: Date.current }
    }

    assert_redirected_to reports_ai_conversations_path
    assert_equal 0, Reporting::Conversation.where(title: "Blocked").count
  end

  test "enabled membership can keep multiple private conversations" do
    Ai::Configuration.current.update!(reports_enabled: true)
    @account.update!(ai_reports_enabled: true)
    @membership.update!(ai_reports_enabled: true)

    2.times do |index|
      post reports_ai_conversations_path, params: {
        reporting_conversation: { title: "Topic #{index}", date_from: Date.current.beginning_of_month, date_to: Date.current }
      }
      assert_response :redirect
    end

    assert_equal 2, @membership.reporting_conversations.where("title LIKE 'Topic %'").count
  end

  test "renders a conversation with its Turbo stream subscription" do
    Ai::Configuration.current.update!(reports_enabled: true)
    @account.update!(ai_reports_enabled: true)
    @membership.update!(ai_reports_enabled: true)
    conversation = @membership.reporting_conversations.create!(
      account: @account,
      title: "Reconciliation",
      date_from: Date.current.beginning_of_month,
      date_to: Date.current
    )

    get reports_ai_conversation_path(conversation)

    assert_response :success
    assert_select "turbo-cable-stream-source"
    assert_select "form[action=?]", reports_ai_conversation_turns_path(conversation)
  end
end
