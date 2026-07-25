# frozen_string_literal: true

require "test_helper"

class Dashboard::PendingTaskRowComponentTest < ViewComponent::TestCase
  setup do
    @account = accounts(:one)
    @user = users(:one)
  end

  test "renders a recurring task with Turbo details and its completion action" do
    task = RecurringTask.create!(
      account: @account,
      name: "Review subscriptions",
      recurrence: "monthly",
      next_due_date: Date.current
    )

    component = Dashboard::PendingTaskRowComponent.new(task: task)
    render_inline(component)

    assert_selector "li[data-task-kind='recurring']"
    assert_selector "a[href='#{component.detail_path}'][data-turbo-frame='task_detail_panel']", text: /Review subscriptions/
    assert_selector "form[action='#{component.completion_path}'] button[type='submit']"
    assert_text I18n.t("task.recurring_tasks.model_name")
  end

  test "renders a project task with drawer details and done status" do
    project = Projects::Project.create!(
      account: @account,
      user: @user,
      name: "Home maintenance",
      status: "active",
      priority: "medium"
    )
    task = Projects::Task.create!(
      account: @account,
      user: @user,
      project: project,
      title: "Replace mirror screw",
      status: "backlog",
      priority: "high",
      due_date: Date.current
    )

    component = Dashboard::PendingTaskRowComponent.new(task: task)
    render_inline(component)

    assert_selector "li[data-task-kind='project']"
    assert_selector "a[href='#{component.detail_path}'][data-dashboard-task-detail='drawer'][onclick*='drawerOpen']"
    assert_selector "form[action='#{component.completion_path}'] input[name='task[status]'][value='done']", visible: :all
    assert_text "Home maintenance"
  end
end
