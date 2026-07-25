require "test_helper"

class DashboardIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = @user.accounts.first || @user.accounts.create!(name: "Test Account")
    sign_in_as(@user, @account)
  end

  test "dashboard renders quick-add menu component" do
    get root_path
    assert_response :success
    assert_select "div.fixed.right-4.z-40.md\\:hidden[data-controller='quick-add-menu']" # FAB on mobile
    assert_select "div.fixed.right-4.z-40.hidden.md\\:flex[data-controller='quick-add-menu']" # Toolbar on desktop
  end

  test "quick add links are present on dashboard" do
    get root_path
    assert_response :success
    assert_select "a[href='#{quick_add_financial_path}']"
  end

  test "dashboard recurring tasks open details and can be marked done" do
    task = RecurringTask.create!(
      account: @account,
      name: "Review subscriptions",
      recurrence: "once",
      next_due_date: Date.current
    )

    get root_path

    assert_response :success
    assert_select "a[href='#{task_recurring_task_path(task, return_to: "dashboard")}'][data-turbo-frame='task_detail_panel']", text: /Review subscriptions/
    assert_select "form[action='#{mark_done_task_recurring_task_path(task, return_to: "dashboard")}'] button[type='submit']"
    assert_select "turbo-frame#task_detail_panel"
    assert_includes css_select("main").first["class"], "px-0"
    assert_includes css_select("main").first["class"], "sm:px-4"

    patch mark_done_task_recurring_task_path(task, return_to: "dashboard")

    assert_redirected_to root_path
    assert_nil task.reload.next_due_date
    assert_not_nil task.last_done_at
  end

  test "dashboard task details keep navigation on the dashboard" do
    task = RecurringTask.create!(
      account: @account,
      name: "Check the budget",
      recurrence: "weekly",
      next_due_date: Date.current
    )

    get task_recurring_task_path(task, return_to: "dashboard")

    assert_response :success
    assert_select "turbo-frame#task_detail_panel"
    assert_select "a[href='#{root_path}'][data-turbo-frame='task_detail_panel']"
    assert_select "form[action='#{mark_done_task_recurring_task_path(task, return_to: "dashboard")}'][data-turbo-frame='_top']"
  end

  test "marking a task done defaults to the tasks page" do
    task = RecurringTask.create!(
      account: @account,
      name: "Default navigation task",
      recurrence: "once",
      next_due_date: Date.current
    )

    patch mark_done_task_recurring_task_path(task)

    assert_redirected_to task_root_path
  end

  test "dashboard includes every kind of pending project task and excludes unavailable tasks" do
    project = create_project("Dashboard project")
    project_task = create_project_task("Project task", due_date: Date.current, project: project)
    unassigned_task = create_project_task("Unassigned task", due_date: Date.current + 1.day)

    company = Career::Company.create!(account: @account, name: "Dashboard Co")
    application = Career::JobApplication.create!(
      account: @account,
      company: company,
      role_title: "Dashboard Engineer",
      status: "saved"
    )
    career_task = create_project_task("Career task", due_date: Date.current + 2.days, taskable: application)
    create_project_task("Completed task", due_date: Date.current, status: "done")
    create_project_task("Other account task", due_date: Date.current, account: accounts(:two), user: users(:two))

    get root_path

    assert_response :success
    assert_select "li[data-task-kind='project']", count: 3
    assert_select "a[href='#{edit_task_task_path(project_task, return_to: "dashboard")}']", text: /Project task/
    assert_select "a[href='#{edit_task_task_path(unassigned_task, return_to: "dashboard")}']", text: /Unassigned task/
    assert_select "a[href='#{edit_task_task_path(career_task, return_to: "dashboard")}']", text: /Career task/
    assert_select "li", text: /Dashboard project/
    assert_select "li", text: /Job Application/
    assert_select "li", text: /Completed task/, count: 0
    assert_select "li", text: /Other account task/, count: 0
    assert_select "div[data-controller='drawer']"
  end

  test "dashboard orders the combined task list and caps it at five" do
    create_project_task("Project overdue", due_date: Date.current - 1.day)
    RecurringTask.create!(account: @account, name: "Recurring oldest", recurrence: "once", next_due_date: Date.current - 2.days)
    create_project_task("High today", due_date: Date.current, priority: "high")
    create_project_task("Low today", due_date: Date.current, priority: "low")
    RecurringTask.create!(account: @account, name: "Recurring tomorrow", recurrence: "once", next_due_date: Date.current + 1.day)
    create_project_task("Undated task", due_date: nil, priority: "high")

    get root_path

    titles = css_select("li[data-task-kind] a > span:first-child > span:first-child").map { |node| node.text.strip }
    assert_equal [ "Recurring oldest", "Project overdue", "High today", "Low today", "Recurring tomorrow" ], titles
  end

  test "dashboard project tasks can be edited and marked done without changing default navigation" do
    task = create_project_task("Finish dashboard task", due_date: Date.current)

    get edit_task_task_path(task, return_to: "dashboard"), headers: { "X-Requested-With" => "XMLHttpRequest" }
    assert_response :success
    assert_select "form[action='#{task_task_path(task, return_to: "dashboard")}']"

    patch task_task_path(task, return_to: "dashboard"), params: { task: { status: "done" } }
    assert_redirected_to root_path
    assert_equal "done", task.reload.status
    assert_not_nil task.completed_at

    patch task_task_path(task, return_to: "external"), params: { task: { status: "backlog" } }
    assert_redirected_to task_root_path
  end

  test "task overlays are mounted outside the main surface and mobile pages use the full shell width" do
    get task_root_path

    assert_response :success
    assert_select "div[data-controller='drawer']", count: 1
    assert_select "turbo-frame#task_detail_panel", count: 1
    assert_select "div[data-drawer-target='panel'].h-dvh.max-h-dvh", count: 1

    drawer = css_select("div[data-controller='drawer']").first
    detail_frame = css_select("turbo-frame#task_detail_panel").first
    main = css_select("main").first
    surface = main.element_children.first

    assert_empty drawer.ancestors("main")
    assert_empty detail_frame.ancestors("main")
    assert_includes main["class"], "px-0"
    assert_includes main["class"], "sm:px-4"
    assert_includes surface["class"], "p-0"
    assert_includes surface["class"], "sm:p-6"
  end

  private

  def create_project(name)
    Projects::Project.create!(
      account: @account,
      user: @user,
      name: name,
      status: "active",
      priority: "medium"
    )
  end

  def create_project_task(title, due_date:, project: nil, taskable: nil, status: "backlog", priority: "medium", account: @account, user: @user)
    Projects::Task.create!(
      account: account,
      user: user,
      project: project,
      taskable: taskable,
      title: title,
      status: status,
      priority: priority,
      due_date: due_date
    )
  end
end
