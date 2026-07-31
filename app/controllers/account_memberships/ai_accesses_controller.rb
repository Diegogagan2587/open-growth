# frozen_string_literal: true

class AccountMemberships::AiAccessesController < ApplicationController
  before_action :set_account_and_membership
  before_action :require_owner

  def update
    unless @account.ai_reports_enabled?
      redirect_to account_account_memberships_path(@account), alert: "A system administrator must enable AI for this account first."
      return
    end

    @membership.update!(ai_access_params)
    redirect_to account_account_memberships_path(@account), notice: "AI access updated for #{@membership.user.name}."
  rescue ActiveRecord::RecordInvalid
    redirect_to account_account_memberships_path(@account), alert: @membership.errors.full_messages.to_sentence
  end

  private

  def set_account_and_membership
    @account = Current.user.accounts.find(params[:account_id])
    @membership = @account.account_memberships.find(params[:account_membership_id])
  end

  def require_owner
    head :forbidden unless @account.account_memberships.find_by(user: Current.user)&.owner?
  end

  def ai_access_params
    params.expect(account_membership: [ :ai_reports_enabled, :ai_reports_monthly_request_limit ])
  end
end
