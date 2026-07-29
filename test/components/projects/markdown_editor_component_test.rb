# frozen_string_literal: true

require "test_helper"

class Projects::MarkdownEditorComponentTest < ViewComponent::TestCase
  test "renders the fallback field, formatting controls, preview, and responsive outlines" do
    doc = Projects::Doc.new(content: "# Draft")
    form = ActionView::Helpers::FormBuilder.new(:doc, doc, vc_test_controller.view_context, {})

    render_inline(Projects::MarkdownEditorComponent.new(form: form, preview_url: "/docs/preview"))

    assert_selector "[data-controller='markdown-editor'][data-markdown-editor-preview-url-value='/docs/preview']"
    assert_selector "textarea[name='doc[content]'][data-markdown-editor-target='textarea']", text: "# Draft"
    assert_selector "[role='tablist'] [role='tab']", count: 2
    assert_selector "[role='toolbar'] button", minimum: 10
    assert_selector "nav[data-markdown-editor-target='outline']", count: 2, visible: :all
    assert_selector "[data-markdown-editor-target='previewContent']"
  end
end
