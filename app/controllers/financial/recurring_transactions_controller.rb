class Financial::RecurringTransactionsController < ApplicationController
  before_action :set_recurring_transaction, only: %i[show edit update destroy]
  before_action :load_form_collections, only: %i[new create edit update]

  def index
    @recurring_transactions = Financial::RecurringTransaction.for_account(Current.account).includes(:category, :source_account).ordered
    @recurring_transactions = @recurring_transactions.where(status: params[:status]) if params[:status].in?(Financial::RecurringTransaction::STATUSES)
    @recurring_transactions = @recurring_transactions.to_a
    with_destination = @recurring_transactions.select(&:destination_account_id?)
    ActiveRecord::Associations::Preloader.new(records: with_destination, associations: :destination_account).call if with_destination.any?
  end

  def show
    @planned_transactions = @recurring_transaction.planned_transactions.includes(:plan, :actual_transaction).order(created_at: :desc)
  end

  def new
    @recurring_transaction = Financial::RecurringTransaction.new(
      frequency: "monthly",
      importance: "normal",
      status: "active",
      budget_consuming: true
    )
  end

  def create
    @recurring_transaction = Financial::RecurringTransaction.new(recurring_transaction_params.merge(account: Current.account))
    return redirect_to(finance_recurring_transaction_path(@recurring_transaction), notice: "Recurring transaction created") if @recurring_transaction.save

    render :new, status: :unprocessable_entity
  end

  def edit; end

  def update
    return redirect_to(finance_recurring_transaction_path(@recurring_transaction), notice: "Recurring transaction updated") if @recurring_transaction.update(recurring_transaction_params)

    render :edit, status: :unprocessable_entity
  end

  def destroy
    if @recurring_transaction.planned_transactions.exists? || @recurring_transaction.planned_expenses.exists?
      @recurring_transaction.update!(status: "archived")
      redirect_to finance_recurring_transactions_path, status: :see_other, notice: "Recurring transaction archived"
    else
      @recurring_transaction.destroy!
      redirect_to finance_recurring_transactions_path, status: :see_other, notice: "Recurring transaction removed"
    end
  end

  private

  def set_recurring_transaction
    @recurring_transaction = Financial::RecurringTransaction.for_account(Current.account).find(params[:id])
  end

  def load_form_collections
    @financial_accounts = Financial::Account.for_account(Current.account).active.order(:account_group, :name)
    @categories = Category.for_account(Current.account).order(:name)
  end

  def recurring_transaction_params
    params.expect(financial_recurring_transaction: [
      :name, :description, :amount, :frequency, :budget_consuming,
      :importance, :status, :category_id, :source_account_id, :destination_account_id, :notes
    ])
  end
end
