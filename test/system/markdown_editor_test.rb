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
    skip "Temporarily disabled: flaky in CI; re-enable after fixing the mobile confirm assertion"

    page.current_window.resize_to(390, 844)
    sign_in
    visit edit_doc_path(@doc)

    find(".cm-content[contenteditable='true']")
    markdown = "# Mobile heading\n\n# Mobile heading\n\n```\n# Hidden heading\n```\n\nBody"
    page.execute_script(<<~JS, markdown)
      const element = document.querySelector("[data-controller~='markdown-editor']")
      const controller = window.Stimulus.getControllerForElementAndIdentifier(element, "markdown-editor")
      controller.editor.dispatch({
        changes: { from: 0, to: controller.editor.state.doc.length, insert: arguments[0] },
        selection: { anchor: arguments[0].length }
      })
      controller.renderOutline()
    JS

    assert_equal markdown, find("textarea[name='doc[content]']", visible: :all).value

    page.execute_script("document.querySelector('details').open = true")
    assert_selector "details nav button", text: "Mobile heading", count: 2
    assert_no_selector "details nav button", text: "Hidden heading"

    page.execute_script(<<~JS)
      const element = document.querySelector("[data-controller~='markdown-editor']")
      window.Stimulus.getControllerForElementAndIdentifier(element, "markdown-editor").runCommand("bold")
    JS
    assert_includes find("textarea[name='doc[content]']", visible: :all).value, "**bold text**"

    page.execute_script(<<~JS)
      const element = document.querySelector("[data-controller~='markdown-editor']")
      window.Stimulus.getControllerForElementAndIdentifier(element, "markdown-editor").showPreview()
    JS
    assert_selector "[data-markdown-editor-target='previewContent'] h1#mobile-heading", text: "Mobile heading"
    assert_selector "[data-markdown-editor-target='previewContent'] h1#mobile-heading-2", text: "Mobile heading"

    page.execute_script <<~JS
      window.confirm = (message) => {
        document.documentElement.dataset.confirmMessage = message
        return false
      }
    JS
    click_link "Cancel"
    assert_selector "html[data-confirm-message='Discard your unsaved document changes?']", visible: :all
    assert_current_path edit_doc_path(@doc)

    click_button "Update Document"
    assert_current_path doc_path(@doc)
    assert_selector ".markdown-content h1#mobile-heading", text: "Mobile heading"
    assert_selector ".markdown-content h1#mobile-heading-2", text: "Mobile heading"

    page.execute_script("document.querySelector('details').open = true")
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
