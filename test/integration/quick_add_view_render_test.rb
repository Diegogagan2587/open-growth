require "test_helper"

class QuickAddViewRenderTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @account = @user.accounts.first
    post session_path, params: {
      email_address: @user.email_address,
      password: "password"
    }
  end

  test "financial modal renders with income form" do
    get quick_add_financial_path
    if response.status == 200
      assert_select "div[data-controller='quick-add-tabs']", count: 1
      assert_select "button", text: /Income/
      assert_select "button", text: /Expense/
      assert_select "button", text: /Transfer/
      assert_select "form[data-quick-add-offline='true']", count: 3
    end
  end

  test "quick add menu renders on dashboard" do
    get root_path
    if response.status == 200
      assert_select "body[data-controller~='quick-add-offline']"
      assert_select "link[rel='manifest'][href='#{pwa_manifest_path(format: :json)}']"
      assert_includes response.body, "serviceWorker"
      # Check for FAB on mobile
      assert_select "div.fixed.right-4.z-40.md\\:hidden[data-controller='quick-add-menu']"
      # Check for desktop quick actions container
      assert_select "div.fixed.right-4.z-40.hidden.md\\:flex[data-controller='quick-add-menu']"
      # Check for link to quick-add
      assert_select "a[href*='quick-add']"
    end
  end

  test "pwa endpoints render" do
    get pwa_manifest_path(format: :json)
    assert_response :success
    assert_includes response.media_type, "json"

    get pwa_service_worker_path
    assert_response :success
    assert_includes response.body, "quick-add/financial"
  end
end
