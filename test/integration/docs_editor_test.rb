require "test_helper"

class DocsEditorIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = accounts(:one)
    sign_in_as(@user, @account)
    @project = Projects::Project.create!(
      account: @account,
      user: @user,
      name: "Editor project",
      status: "active",
      priority: "medium"
    )
    @doc = Projects::Doc.create!(account: @account, title: "Editor doc", doc_type: "note", content: "# Existing")
    @project.docs << @doc
  end

  test "standalone and project document forms use the shared markdown editor" do
    [ new_doc_path, edit_doc_path(@doc), new_project_doc_path(@project), edit_project_doc_path(@project, @doc) ].each do |path|
      get path

      assert_response :success
      assert_select "form [data-controller='markdown-editor']", count: 1
      assert_select "textarea[name='doc[content]']", count: 1
      assert_select "[data-markdown-editor-preview-url-value='#{preview_docs_path}']", count: 1
    end
  end

  test "preview renders supported markdown and sanitizes unsafe HTML" do
    post preview_docs_path, params: {
      content: "# Preview\n\n**Safe** <script>alert(1)</script> [bad](javascript:alert(1))"
    }

    assert_response :success
    assert_select "h1", text: "Preview"
    assert_select "strong", text: "Safe"
    assert_select "script", count: 0
    assert_select "a[href^='javascript:']", count: 0
  end

  test "existing standalone and project persistence behavior is preserved" do
    assert_difference("Projects::Doc.count", 2) do
      post docs_path, params: { doc: { title: "Standalone draft", doc_type: "note", content: "# Standalone" } }
      assert_redirected_to doc_path(Projects::Doc.find_by!(title: "Standalone draft"))

      post project_docs_path(@project), params: { doc: { title: "Project draft", doc_type: "note", content: "# Project" } }
      project_doc = Projects::Doc.find_by!(title: "Project draft")
      assert_redirected_to project_doc_path(@project, project_doc)
      assert_includes @project.docs.reload, project_doc
    end

    patch doc_path(@doc), params: { doc: { title: @doc.title, doc_type: @doc.doc_type, content: "## Updated" } }
    assert_redirected_to doc_path(@doc)
    assert_equal "## Updated", @doc.reload.content
  end

  test "validation errors keep the markdown editor and submitted content" do
    post docs_path, params: { doc: { title: "", doc_type: "note", content: "# Unsaved draft" } }

    assert_response :success
    assert_select "[role='alert']", text: /Title can't be blank/
    assert_select "[data-controller='markdown-editor'] textarea", text: "# Unsaved draft"
  end

  test "full document readers include the generated outline component" do
    [ doc_path(@doc), project_doc_path(@project, @doc) ].each do |path|
      get path

      assert_response :success
      assert_select "[data-controller='markdown-outline']", count: 1
      assert_select ".markdown-content h1", text: "Existing"
      assert_select "nav[data-markdown-outline-target='outline']", count: 2
    end
  end

  test "preview requires authentication" do
    delete session_path
    post preview_docs_path, params: { content: "# Private" }

    assert_redirected_to new_session_path
  end
end
