require "test_helper"

class Career::JobApplicationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = accounts(:one)
    sign_in_as(@user, @account)

    @company = Career::Company.create!(account: @account, name: "Acme Corp")
    @job_application = Career::JobApplication.create!(
      account: @account,
      company: @company,
      role_title: "Rails Engineer",
      status: "saved"
    )
  end

  test "should get index" do
    get career_job_applications_path
    assert_response :success
    assert_select "h1", "Career applications"
  end

  test "should create job application" do
    assert_difference("Career::JobApplication.count", 1) do
      post career_job_applications_path, params: {
        career_job_application: {
          company_name: "New Co",
          role_title: "Backend",
          status: "saved"
        }
      }
    end

    assert_redirected_to career_job_application_path(Career::JobApplication.last)
  end

  test "should update status" do
    patch career_job_application_path(@job_application), params: {
      career_job_application: {
        status: "applied"
      }
    }

    assert_redirected_to career_job_application_path(@job_application)
    assert_equal "applied", @job_application.reload.status
  end

  test "should filter by needs action" do
    Projects::Task.create!(
      account: @account,
      user: @user,
      title: "Follow up",
      status: "backlog",
      priority: "medium",
      taskable: @job_application
    )

    get career_job_applications_path, params: { needs_action: "1" }
    assert_response :success
    assert_select "h2", text: /Rails Engineer/
  end

  test "should create suggested task" do
    assert_difference("Projects::Task.count", 1) do
      post create_suggested_task_career_job_application_path(@job_application), params: { template_key: "research_company" }
    end

    assert_redirected_to career_job_application_path(@job_application)
    task = Projects::Task.order(:created_at).last
    assert_equal @job_application, task.taskable
    assert_equal "career_template", task.metadata["source"]
    assert_equal "research_company", task.metadata["template_key"]
  end

  test "should prevent duplicate pending suggested task" do
    Projects::Task.create!(
      account: @account,
      user: @user,
      taskable: @job_application,
      title: "Research company",
      status: "backlog",
      priority: "medium",
      metadata: { source: "career_template", template_key: "research_company" }
    )

    assert_no_difference("Projects::Task.count") do
      post create_suggested_task_career_job_application_path(@job_application), params: { template_key: "research_company" }
    end

    assert_redirected_to career_job_application_path(@job_application)
  end

  test "show links documents to career doc panel" do
    doc = Projects::Doc.create!(
      account: @account,
      documentable: @job_application,
      title: "Interview notes",
      doc_type: "note",
      content: "Bring up **Rails** work."
    )

    get career_job_application_path(@job_application)

    assert_response :success
    assert_select "a[data-turbo-frame='career_doc_panel'][href='#{doc_path(doc)}']", text: "Interview notes"
  end

  test "career doc panel renders document content" do
    doc = Projects::Doc.create!(
      account: @account,
      documentable: @job_application,
      title: "Interview notes",
      doc_type: "note",
      content: "Bring up **Rails** work."
    )

    get doc_path(doc), headers: { "Turbo-Frame" => "career_doc_panel" }

    assert_response :success
    assert_select "turbo-frame#career_doc_panel"
    assert_select "h2", "Interview notes"
    assert_select "a[href='#{edit_doc_path(doc)}']", "Edit"
    assert_select ".markdown-content strong", "Rails"
  end
end
