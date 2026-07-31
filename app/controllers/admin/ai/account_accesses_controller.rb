# frozen_string_literal: true

class Admin::Ai::AccountAccessesController < AdminController
  def update
    account = Account.find(params[:id])
    account.update!(ai_reports_enabled: ActiveModel::Type::Boolean.new.cast(params[:enabled]))
    redirect_to admin_ai_configuration_path, notice: "AI access updated for #{account.name}."
  end
end
