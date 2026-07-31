require "test_helper"

class Reporting::AnswerQuestionTest < ActiveSupport::TestCase
  Usage = Struct.new(:input_tokens, :output_tokens, :input_tokens_details)
  InputDetails = Struct.new(:cached_tokens)
  IncompleteDetails = Struct.new(:reason)
  Response = Struct.new(:id, :model, :output_text, :usage, :status, :incomplete_details)

  class FakeResponses
    attr_reader :params, :calls

    def initialize(output_text: "No confirmed gaps.", status: :completed, incomplete_reason: nil, error: nil)
      @output_text = output_text
      @status = status
      @incomplete_reason = incomplete_reason
      @error = error
      @calls = 0
    end

    def create(**params)
      @calls += 1
      @params = params
      raise @error if @error

      Response.new(
        "resp_123",
        "gpt-5.6-luna",
        @output_text,
        Usage.new(100, 20, InputDetails.new(10)),
        @status,
        IncompleteDetails.new(@incomplete_reason)
      )
    end
  end

  class FakeClient
    attr_reader :responses

    def initialize(**options)
      @responses = FakeResponses.new(**options)
    end
  end

  setup do
    Ai::Configuration.current.update!(reports_enabled: true)
    @account = accounts(:one)
    @account.update!(ai_reports_enabled: true)
    @membership = account_memberships(:one)
    @membership.update!(ai_reports_enabled: true)
    @conversation = Reporting::Conversation.create!(
      account: @account,
      account_membership: @membership,
      title: "Test analysis",
      date_from: Date.current.beginning_of_month,
      date_to: Date.current
    )
    @turn = @conversation.turns.create!(question: "Are there gaps?")
    Reporting::UsageEvent.create!(account: @account, user: @membership.user, account_membership: @membership, conversation: @conversation, turn: @turn, model: "gpt-5.6-luna")
  end

  test "completes a turn and records provider usage without tools" do
    client = FakeClient.new

    Reporting::AnswerQuestion.new(turn: @turn, client:).call

    assert_equal "completed", @turn.reload.status
    assert_equal "No confirmed gaps.", @turn.answer
    assert_equal 100, @turn.usage_event.input_tokens
    assert_equal 20, @turn.usage_event.output_tokens
    assert_equal 4_000, client.responses.params[:max_output_tokens]
    assert_equal false, client.responses.params[:store]
    assert_empty client.responses.params.fetch(:tools, [])
  end

  test "uses the model selected by the system administrator" do
    configuration = Ai::Configuration.current
    configuration.update!(model: "gpt-configured-model")
    client = FakeClient.new

    Reporting::AnswerQuestion.new(turn: @turn, client:, configuration:).call

    assert_equal "gpt-configured-model", client.responses.params[:model]
    assert_equal "gpt-5.6-luna", @turn.reload.model
  end

  test "cancels without a provider when the client is missing" do
    Reporting::AnswerQuestion.new(turn: @turn, client: nil).call

    assert_equal "failed", @turn.reload.status
    assert_equal "canceled", @turn.usage_event.status
    assert_equal "missing_api_key", @turn.error_code
  end

  test "rejects a request once the membership reaches its monthly cap" do
    @membership.update!(ai_reports_monthly_request_limit: 1)

    assert_raises(Reporting::AnswerQuestion::QuotaExceeded) do
      Reporting::AnswerQuestion.enqueue!(conversation: @conversation, question: "One more question")
    end
  end

  test "rechecks access after enqueue and does not contact the provider" do
    client = FakeClient.new
    @membership.update!(ai_reports_enabled: false)

    Reporting::AnswerQuestion.new(turn: @turn, client:).call

    assert_equal 0, client.responses.calls
    assert_equal "failed", @turn.reload.status
    assert_equal "canceled", @turn.usage_event.status
    assert_equal "access_disabled", @turn.error_code
  end

  test "does not execute an already processed turn twice" do
    client = FakeClient.new

    2.times { Reporting::AnswerQuestion.new(turn: @turn.reload, client:).call }

    assert_equal 1, client.responses.calls
    assert_equal "completed", @turn.reload.status
  end

  test "records an empty provider response as a counted failure" do
    client = FakeClient.new(output_text: "")

    Reporting::AnswerQuestion.new(turn: @turn, client:).call

    assert_equal "failed", @turn.reload.status
    assert_equal "provider_failed", @turn.usage_event.status
    assert_equal "empty_response", @turn.error_code
  end

  test "does not present an incomplete provider response as a complete answer" do
    client = FakeClient.new(output_text: "## Partial answer\n\nThis was cut", status: :incomplete, incomplete_reason: :max_output_tokens)

    Reporting::AnswerQuestion.new(turn: @turn, client:).call

    assert_equal "failed", @turn.reload.status
    assert_nil @turn.answer
    assert_equal "provider_failed", @turn.usage_event.status
    assert_equal "max_output_tokens", @turn.error_code
  end

  test "records provider exceptions without retrying the call" do
    client = FakeClient.new(error: Timeout::Error.new("provider timeout"))

    Reporting::AnswerQuestion.new(turn: @turn, client:).call

    assert_equal 1, client.responses.calls
    assert_equal "failed", @turn.reload.status
    assert_equal "provider_failed", @turn.usage_event.status
    assert_equal "timeout_error", @turn.error_code
  end
end
