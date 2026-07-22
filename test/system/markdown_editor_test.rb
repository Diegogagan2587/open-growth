require "application_system_test_case"

class MarkdownEditorTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @account = accounts(:one)
    @doc = Projects::Doc.create!(
      account: @account,
      title: "Browser editor doc",
      doc_type: "note",
      content: "# Original"
    )
  end

  test "writes, previews, outlines, protects, and saves markdown on mobile" do
    page.current_window.resize_to(390, 844)
    sign_in
    visit edit_doc_path(@doc)

    editor = find(".cm-content[contenteditable='true']")
    editor.click
    markdown = "# Mobile heading\n\n# Mobile heading\n\n```\n# Hidden heading\n```\n\nBody"
    editor.send_keys([ :control, "a" ], markdown)

    assert_equal markdown, find("textarea[name='doc[content]']", visible: :all).value

    find("details summary", text: "Outline").click
    assert_selector "details nav button", text: "Mobile heading", count: 2
    assert_no_selector "details nav button", text: "Hidden heading"

    editor.send_keys([ :control, "b" ])
    assert_includes find("textarea[name='doc[content]']", visible: :all).value, "**bold text**"

    click_button "Preview"
    assert_selector "[data-markdown-editor-target='previewContent'] h1#mobile-heading", text: "Mobile heading"
    assert_selector "[data-markdown-editor-target='previewContent'] h1#mobile-heading-2", text: "Mobile heading"

    dismiss_confirm("Discard your unsaved document changes?") { click_link "Cancel" }
    assert_current_path edit_doc_path(@doc)

    click_button "Update Document"
    assert_current_path doc_path(@doc)
    assert_selector ".markdown-content h1#mobile-heading", text: "Mobile heading"
    assert_selector ".markdown-content h1#mobile-heading-2", text: "Mobile heading"

    find("details summary", text: "Outline").click
    assert_selector "details nav a[href='#mobile-heading']", text: "Mobile heading"
  end

  private

  def sign_in
    visit new_session_path
    fill_in "email_address", with: @user.email_address
    fill_in "password", with: "password"
    click_button I18n.t("sessions.submit")
    assert_no_current_path new_session_path
  end
end
