require "test_helper"

class Ai::ConfigurationTest < ActiveSupport::TestCase
  test "current returns one configuration with safe defaults" do
    Ai::Configuration.delete_all

    first = Ai::Configuration.current
    second = Ai::Configuration.current

    assert_equal first, second
    assert_not first.reports_enabled?
    assert_equal 50, first.default_monthly_request_limit
    assert_equal "openai", first.provider
    assert_equal "gpt-5.6-luna", first.model
  end

  test "encrypts a configured OpenAI API key" do
    configuration = Ai::Configuration.current
    configuration.update!(openai_api_key: "sk-test-secret")

    stored_value = Ai::Configuration.connection.select_value(
      "SELECT openai_api_key FROM ai_configurations WHERE id = #{configuration.id}"
    )

    assert_equal "sk-test-secret", configuration.reload.openai_api_key
    assert_not_equal "sk-test-secret", stored_value
    assert configuration.credentials_configured?
  end
end
