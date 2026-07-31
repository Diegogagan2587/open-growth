require "test_helper"

class Admin::Ai::ConfigurationsControllerTest < ActionDispatch::IntegrationTest
  test "rejects ordinary users" do
    sign_in_as(users(:one), accounts(:one))
    get admin_ai_configuration_path
    assert_response :forbidden
  end

  test "allows system administrators without exposing conversation content" do
    user = users(:one)
    user.update!(system_admin: true)
    sign_in_as(user, accounts(:one))

    get admin_ai_configuration_path

    assert_response :success
    assert_select "h1", text: "AI operations"
  end

  test "system administrators configure the provider model and credential" do
    user = users(:one)
    user.update!(system_admin: true)
    sign_in_as(user, accounts(:one))

    patch admin_ai_configuration_path, params: {
      ai_configuration: {
        reports_enabled: "1",
        provider: "openai",
        model: "gpt-5.6-luna",
        openai_api_key: "sk-test-admin",
        default_monthly_request_limit: 40,
        maximum_monthly_request_limit: 100
      }
    }

    assert_redirected_to admin_ai_configuration_path
    configuration = Ai::Configuration.current.reload
    assert configuration.reports_enabled?
    assert_equal "openai", configuration.provider
    assert_equal "gpt-5.6-luna", configuration.model
    assert_equal "sk-test-admin", configuration.openai_api_key
  end

  test "a blank credential keeps the configured API key" do
    user = users(:one)
    user.update!(system_admin: true)
    sign_in_as(user, accounts(:one))
    configuration = Ai::Configuration.current
    configuration.update!(openai_api_key: "sk-existing")

    patch admin_ai_configuration_path, params: {
      ai_configuration: {
        reports_enabled: "0",
        provider: "openai",
        model: "gpt-5.6-luna",
        openai_api_key: "",
        default_monthly_request_limit: 50,
        maximum_monthly_request_limit: 500
      }
    }

    assert_equal "sk-existing", configuration.reload.openai_api_key
  end
end
