# frozen_string_literal: true

require "test_helper"

class Ui::ButtonComponentTest < ViewComponent::TestCase
  test "renders icon content with an explicit accessible label" do
    render_inline(Ui::ButtonComponent.new(aria_label: "Move Rent up", size: :icon)) { "<svg></svg>".html_safe }

    assert_css "button[aria-label='Move Rent up'] svg"
    assert_no_css "button", text: "Move Rent up"
  end
end
