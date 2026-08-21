class Financial::TransactionsController < ApplicationController
  before_action :set_transaction, only: %i[show edit update destroy]
  before_action :load_form_collections, only: %i[new create edit update]

  def index
    @financial_entries = Financial::Transaction.for_account(Current.account).includes(:category, :source_account, :destination_account).by_date
    account_id = params[:account_id].to_s if params[:account_id].to_s.match?(/\A\d+\z/)
    @financial_entries = @financial_entries.where("source_account_id = :id OR destination_account_id = :id", id: account_id) if account_id
    @financial_entries = @financial_entries.where("transaction_date >= ?", params[:date_from]) if params[:date_from].present?
    @financial_entries = @financial_entries.where("transaction_date <= ?", params[:date_to]) if params[:date_to].present?
    @financial_entries = @financial_entries.where(category_id: params[:category_id]) if params[:category_id].present?
    @financial_entries = @financial_entries.where("financial_transactions.description ILIKE ?", "%#{params[:q]}%") if params[:q].present?
    @financial_entries = @financial_entries.where(transaction_type: params[:transaction_type]) if params[:transaction_type].in?(Financial::Transaction.transaction_types)
    @financial_entries = @financial_entries.public_send(params[:reconciliation]) if params[:reconciliation].in?(%w[reconciled unreconciled])
    @financial_entries = @financial_entries.to_a
    @account_filter_options = Financial::Account.for_account(Current.account).active.order(:account_group, :name)
    @categories = Category.for_account(Current.account).order(:name)
  end

  def show
  end

  def new
    @financial_entry = Financial::Transaction.new(transaction_date: Date.current, transaction_type: params[:transaction_type].presence || "expense")
    @financial_entry.plan = Financial::Plan.for_account(Current.account).find_by(id: params[:plan_id])
  end

  def create
    @financial_entry = Financial::Transaction.new(transaction_params.merge(account: Current.account))
    if @financial_entry.save
      redirect_to finance_transaction_path(@financial_entry), notice: "Transaction created"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @financial_entry.correct!(transaction_params)
    redirect_to finance_transaction_path(@financial_entry), notice: "Transaction updated"
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_entity
  end

  def destroy
    @financial_entry.remove!
    redirect_to finance_transactions_path, status: :see_other, notice: "Transaction removed"
  rescue ActiveRecord::RecordInvalid => error
    redirect_to finance_transaction_path(@financial_entry), alert: error.record.errors.full_messages.to_sentence
  end

  private

  def set_transaction
    @financial_entry = Financial::Transaction.for_account(Current.account).find(params[:id])
  end

  def transaction_params
    params.expect(financial_transaction: [
      :transaction_type, :transaction_date, :entry_time, :amount, :description, :notes,
      :source_account_id, :destination_account_id, :plan_id, :category_id, :budget_period_id
    ])
  end

  def load_form_collections
    @financial_accounts = Financial::Account.for_account(Current.account).active.order(:account_group, :name)
    @financial_liabilities = @financial_accounts.select(&:liability?)
    @income_events = Financial::Plan.for_account(Current.account).chronological
    @categories = Category.for_account(Current.account).order(:name)
    @budget_periods = BudgetPeriod.for_account(Current.account).order(start_date: :desc)
  end
end
