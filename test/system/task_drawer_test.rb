require "application_system_test_case"

class TaskDrawerTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
  end

  test "task drawer fills the mobile viewport after scrolling" do
    page.current_window.resize_to(390, 844)
    visit new_session_path
    fill_in "email_address", with: @user.email_address
    fill_in "password", with: "password"
    click_button I18n.t("sessions.submit")
    assert_no_field "email_address"
    visit root_path
    assert_selector "[data-drawer-target='panel']", visible: :all

    page.execute_script(<<~JAVASCRIPT)
      document.body.insertAdjacentHTML(
        "beforeend",
        '<div id="task-drawer-test-spacer" style="height: 1200px"></div>'
      )
      window.scrollTo(0, document.body.scrollHeight)
    JAVASCRIPT
    assert_operator page.evaluate_script("window.scrollY"), :>, 0
    panel = find("[data-drawer-target='panel']", visible: :all)
    page.execute_script("arguments[0].classList.remove('hidden')", panel)
    rectangle = page.evaluate_script("arguments[0].getBoundingClientRect().toJSON()", panel)
    viewport_height = page.evaluate_script("window.innerHeight")
    viewport_width = page.evaluate_script("document.documentElement.clientWidth")

    assert_in_delta 0, rectangle.fetch("top"), 1
    assert_in_delta viewport_height, rectangle.fetch("height"), 1
    assert_in_delta viewport_width, page.evaluate_script("document.querySelector('main').getBoundingClientRect().width"), 1
  end
end
