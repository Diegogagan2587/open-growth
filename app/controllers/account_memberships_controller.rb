class AccountMembershipsController < ApplicationController
  before_action :set_account
  before_action :ensure_owner
  before_action :set_membership, only: [ :update, :destroy ]

  def index
    @memberships = @account.account_memberships.includes(:user)
  end

  def create
    email = params[:email_address]&.strip&.downcase
    user = User.find_by(email_address: email)

    if user.nil?
      redirect_to account_account_memberships_path(@account), alert: t("account_memberships.flash.user_not_found", email: email)
      return
    end

    if @account.users.include?(user)
      redirect_to account_account_memberships_path(@account), alert: "User is already a member of this account."
      return
    end

    @membership = @account.account_memberships.build(
      user: user,
      role: params[:role] || "member",
      ai_reports_monthly_request_limit: Ai::Configuration.current.default_monthly_request_limit
    )

    respond_to do |format|
      if @membership.save
        format.html { redirect_to account_account_memberships_path(@account), notice: t("account_memberships.flash.added") }
        format.json { render :show, status: :created }
      else
        format.html { redirect_to account_account_memberships_path(@account), alert: t("account_memberships.flash.add_failed", errors: @membership.errors.full_messages.join(", ")) }
        format.json { render json: @membership.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @membership.update(membership_params)
        format.html { redirect_to account_account_memberships_path(@account), notice: t("account_memberships.flash.updated") }
        format.json { render :show, status: :ok }
      else
        format.html { redirect_to account_account_memberships_path(@account), alert: t("account_memberships.flash.update_failed", errors: @membership.errors.full_messages.join(", ")) }
        format.json { render json: @membership.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    # Prevent removing the last owner
    if @membership.owner? && @account.account_memberships.owners.count == 1
      redirect_to account_account_memberships_path(@account), alert: t("account_memberships.flash.cannot_remove_last_owner")
      return
    end

    @membership.destroy!

    respond_to do |format|
      format.html { redirect_to account_account_memberships_path(@account), status: :see_other, notice: t("account_memberships.flash.removed") }
      format.json { head :no_content }
    end
  end

  private

  def set_account
    @account = Account.find(params[:account_id])
    unless Current.user.accounts.include?(@account)
      redirect_to accounts_path, alert: "You don't have access to this account."
    end
  end

  def ensure_owner
    unless @account.account_memberships.find_by(user: Current.user)&.owner?
      redirect_to @account, alert: t("account_memberships.alert_owners_only")
    end
  end

  def set_membership
    @membership = @account.account_memberships.find(params[:id])
  end

  def membership_params
    params.expect(account_membership: [ :role ])
  end
end
