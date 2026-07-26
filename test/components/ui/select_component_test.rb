require "test_helper"

class Ui::SelectComponentTest < ViewComponent::TestCase
  test "renders a native select by default" do
    render_inline(Ui::SelectComponent.new(name: "category_id", options: [[ "Food", 1 ]]))

    assert_selector "select[name='category_id']"
    assert_no_selector "[data-controller='searchable-select']"
  end

  test "renders searchable controls while preserving the named select" do
    render_inline(Ui::SelectComponent.new(
      name: "category_id",
      options: [[ "Food", 1 ], [ "Transportation", 2 ]],
      include_blank: "Select category",
      required: true,
      searchable: true
    ))

    assert_selector "[data-controller='searchable-select']"
    assert_selector "input[role='combobox'][required][placeholder='Select category']"
    assert_selector "select[name='category_id'][required][data-searchable-select-target='select']"
    assert_selector "button[data-label='Transportation'][data-value='2']"
    assert_text "No matches found"
  end
end
