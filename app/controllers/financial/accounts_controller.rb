class Financial::AccountsController < ApplicationController
  before_action :set_financial_account, only: %i[show edit update destroy]

  def index
    @financial_accounts = Financial::Account.for_account(Current.account).order(:account_group, :name)
    @financial_accounts = @financial_accounts.where(account_group: params[:account_group]) if params[:account_group].in?(Financial::Account::ACCOUNT_GROUPS)
  end

  def show; end

  def new
    @financial_account = Financial::Account.new(account_group: params[:account_group].presence || "asset", status: "active", opening_balance: 0)
  end

  def create
    @financial_account = Financial::Account.new(financial_account_params.merge(account: Current.account))
    if @financial_account.save
      redirect_to finance_account_path(@financial_account), notice: "Financial account created"
    else
      flash.now[:alert] = @financial_account.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @financial_account.update(financial_account_params)
      redirect_to finance_account_path(@financial_account), notice: "Financial account updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @financial_account.transactions.exists?
      redirect_to finance_account_path(@financial_account), alert: "Archive accounts with transaction history"
    else
      @financial_account.destroy!
      redirect_to finance_accounts_path, status: :see_other, notice: "Financial account removed"
    end
  end

  private

  def set_financial_account
    @financial_account = Financial::Account.for_account(Current.account).find(params[:id])
  end

  def financial_account_params
    params.expect(financial_account: %i[name account_group account_type status opening_balance credit_limit notes])
  end
end
