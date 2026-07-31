# frozen_string_literal: true

class Admin::Ai::ConfigurationsController < AdminController
  def show
    load_dashboard
  end

  def update
    @configuration = Ai::Configuration.current

    Ai::Configuration.transaction do
      @configuration.update!(configuration_attributes)
      AccountMembership.where("ai_reports_monthly_request_limit > ?", @configuration.maximum_monthly_request_limit)
        .update_all(ai_reports_monthly_request_limit: @configuration.maximum_monthly_request_limit, updated_at: Time.current)
    end

    redirect_to admin_ai_configuration_path, notice: "AI report controls updated."
  rescue ActiveRecord::RecordInvalid
    load_dashboard
    render :show, status: :unprocessable_entity
  end

  private

  def load_dashboard
    @configuration ||= Ai::Configuration.current
    @accounts = Account.includes(account_memberships: :user).order(:name)
    range = Time.current.beginning_of_month..Time.current.end_of_month
    events = Reporting::UsageEvent.counted.during(range)
    @usage_by_account = events.group(:account_id).count
    @input_tokens_by_account = events.group(:account_id).sum(:input_tokens)
    @output_tokens_by_account = events.group(:account_id).sum(:output_tokens)
    @cached_tokens_by_account = events.group(:account_id).sum(:cached_input_tokens)
    @failures_by_account = events.where(status: "provider_failed").group(:account_id).count
    @recent_failures = events.where(status: "provider_failed").where.not(error_code: nil)
      .includes(:account, :user).order(created_at: :desc).limit(25)
  end

  def configuration_params
    params.expect(ai_configuration: [ :reports_enabled, :provider, :model, :openai_api_key, :default_monthly_request_limit, :maximum_monthly_request_limit ])
  end

  def configuration_attributes
    configuration_params.to_h.tap do |attributes|
      attributes.delete("openai_api_key") if attributes["openai_api_key"].blank?
    end
  end
end
