require "test_helper"

class Career::JobApplication::SuggestedActionsTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:one)
    @user = users(:one)
    @company = Career::Company.create!(account: @account, name: "Template Co")
    @job_application = Career::JobApplication.create!(
      account: @account,
      company: @company,
      role_title: "Rails Engineer",
      status: "applied"
    )
  end

  test "returns templates for the current status" do
    suggestions = @job_application.suggested_actions

    assert suggestions.any?
    assert suggestions.any? { |item| item.key == "send_follow_up" }
  end

  test "hides templates that already exist as pending tasks" do
    Projects::Task.create!(
      account: @account,
      user: @user,
      taskable: @job_application,
      title: "Send follow-up",
      status: "backlog",
      priority: "high",
      metadata: { source: "career_template", template_key: "send_follow_up" }
    )

    suggestions = @job_application.suggested_actions

    assert suggestions.none? { |item| item.key == "send_follow_up" }
  end

  test "shows template again when matching task is completed" do
    Projects::Task.create!(
      account: @account,
      user: @user,
      taskable: @job_application,
      title: "Send follow-up",
      status: "done",
      priority: "high",
      metadata: { source: "career_template", template_key: "send_follow_up" }
    )

    suggestions = @job_application.suggested_actions

    assert suggestions.any? { |item| item.key == "send_follow_up" }
  end
end
