# frozen_string_literal: true

require "test_helper"

class Ui::CardComponentTest < ViewComponent::TestCase
  test "renders card with default size" do
    render_inline(Ui::CardComponent.new) { "Card content" }
    assert_selector "div.rounded-lg.border.border-border.bg-card.text-card-foreground.p-6"
  end

  test "renders card with sm size" do
    render_inline(Ui::CardComponent.new(size: :sm)) { "Card content" }
    assert_selector "div.rounded-lg.border.border-border.bg-card.text-card-foreground.p-4"
  end

  test "renders card with custom css class" do
    render_inline(Ui::CardComponent.new(css_class: "shadow-lg")) { "Card content" }
    assert_selector "div.shadow-lg"
  end

  test "renders card header" do
    render_inline(Ui::CardHeaderComponent.new) { "Header" }
    assert_selector "div.relative.flex.flex-col.space-y-1\\.5.mb-4"
  end

  test "renders card title" do
    render_inline(Ui::CardTitleComponent.new) { "Title" }
    assert_selector "h2.text-2xl.font-semibold.leading-none.tracking-tight"
    assert_text "Title"
  end

  test "renders card description" do
    render_inline(Ui::CardDescriptionComponent.new) { "Description text" }
    assert_selector "p.text-sm.text-muted-foreground"
    assert_text "Description text"
  end

  test "renders card action" do
    render_inline(Ui::CardActionComponent.new) { "Action" }
    assert_selector "div.absolute.top-4.right-4"
    assert_text "Action"
  end

  test "renders card content" do
    render_inline(Ui::CardContentComponent.new) { "Main content" }
    assert_selector "div"
    assert_text "Main content"
  end

  test "renders card footer" do
    render_inline(Ui::CardFooterComponent.new) { "Footer buttons" }
    assert_selector "div.flex.items-center.pt-0.mt-4"
    assert_text "Footer buttons"
  end

  test "card accepts custom class on all sub-components" do
    render_inline(Ui::CardHeaderComponent.new(css_class: "custom-header")) do
      "Header"
    end
    assert_selector "div.custom-header"

    render_inline(Ui::CardTitleComponent.new(css_class: "custom-title")) do
      "Title"
    end
    assert_selector "h2.custom-title"

    render_inline(Ui::CardContentComponent.new(css_class: "custom-content")) do
      "Content"
    end
    assert_selector "div.custom-content"
  end

  test "normalizes size variants" do
    render_inline(Ui::CardComponent.new(size: "default")) { "Card" }
    assert_selector "div.p-6"

    render_inline(Ui::CardComponent.new(size: "sm")) { "Card" }
    assert_selector "div.p-4"
  end

  test "defaults to default size on invalid variant" do
    render_inline(Ui::CardComponent.new(size: :invalid)) { "Card" }
    assert_selector "div.p-6"
  end
end
