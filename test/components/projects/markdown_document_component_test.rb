# frozen_string_literal: true

require "test_helper"

class Projects::MarkdownDocumentComponentTest < ViewComponent::TestCase
  test "renders sanitized markdown with mobile and desktop outline targets" do
    render_inline(Projects::MarkdownDocumentComponent.new(markdown: "# Safe\n\n**Body**<script>alert(1)</script>"))

    assert_selector "[data-controller='markdown-outline']"
    assert_selector ".markdown-content h1", text: "Safe"
    assert_selector ".markdown-content strong", text: "Body"
    assert_no_selector "script"
    assert_selector "nav[data-markdown-outline-target='outline']", count: 2, visible: :all
  end
end
