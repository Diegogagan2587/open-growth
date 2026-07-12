# frozen_string_literal: true

require "test_helper"

class AppSidebarComponentTest < ViewComponent::TestCase
  def test_component_renders_sidebar_structure_and_links
    rendered = render_inline(AppSidebarComponent.new(current_controller: "finance"))

    assert rendered.css("aside[data-slot='sidebar']").any?
    assert rendered.css("div[data-slot='sidebar-mobile']").any?
    assert_includes rendered.text, I18n.t("nav.dashboard")
    assert_includes rendered.text, I18n.t("nav.budgets")
    assert_includes rendered.text, "Finance"
    assert rendered.css("a[href='/finance/entries?entry_type=expenses']").any?
    assert_equal 2, rendered.css("a[href='/finance'][data-active='true']").count
  end
end
