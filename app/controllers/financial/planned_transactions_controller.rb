class Financial::PlannedTransactionsController < ApplicationController
  before_action :set_plan, only: [ :index, :create ]
  before_action :set_planned_transaction, only: [ :update, :destroy, :apply, :move ]

  def index
    @planned_transactions = @plan ? @plan.planned_transactions.by_position : Financial::PlannedTransaction.for_account(Current.account).unassigned.order(:planned_for, :created_at)
    @plans = Financial::Plan.for_account(Current.account).where(lifecycle_status: %w[draft active]).chronological unless @plan
  end

  def create
    transaction = @plan.planned_transactions.new(planned_transaction_params.merge(account: Current.account, status: "pending_to_pay"))
    if transaction.save
      redirect_to finance_plan_path(@plan), notice: "Planned transaction added"
    else
      redirect_to finance_plan_path(@plan), alert: transaction.errors.full_messages.to_sentence
    end
  end

  def update
    if @planned_transaction.execution_status == "pending" && @planned_transaction.update(planned_transaction_params)
      redirect_to finance_plan_path(@planned_transaction.plan), notice: "Planned transaction updated"
    else
      redirect_to finance_plan_path(@planned_transaction.plan), alert: @planned_transaction.errors.full_messages.to_sentence.presence || "Only pending transactions can be edited"
    end
  end

  def destroy
    plan = @planned_transaction.plan
    if @planned_transaction.execution_status == "pending" && @planned_transaction.destroy
      redirect_to finance_plan_path(plan), status: :see_other, notice: "Planned transaction removed"
    else
      redirect_to finance_plan_path(plan), alert: "Only pending transactions can be removed"
    end
  end

  def apply
    result = Financial::PlannedTransactions::ApplyService.call(
      planned_transaction: @planned_transaction,
      amount: apply_params[:amount],
      interest_amount: apply_params[:interest_amount],
      entry_date: apply_params[:entry_date],
      description: apply_params[:description],
      category: scoped_category(apply_params[:category_id]),
      financial_account: scoped_asset(apply_params[:financial_account_id]),
      counterparty_financial_account: scoped_asset(apply_params[:counterparty_financial_account_id]),
      financial_liability: scoped_liability(apply_params[:financial_liability_id])
    )
    redirect_back fallback_location: finance_planned_transactions_path,
      notice: ("Transaction applied" if result.success?),
      alert: (result.error_message unless result.success?)
  end

  def move
    target = Financial::Plan.for_account(Current.account).find_by(id: params[:target_plan_id]) if params[:target_plan_id].present?
    result = Financial::PlannedTransactions::MoveService.call(planned_transaction: @planned_transaction, target_plan: target)
    redirect_back fallback_location: finance_planned_transactions_path,
      notice: ("Transaction moved" if result.success?),
      alert: (result.error_message unless result.success?)
  end

  private

  def set_plan
    @plan = Financial::Plan.for_account(Current.account).find(params[:plan_id]) if params[:plan_id]
  end

  def set_planned_transaction
    @planned_transaction = Financial::PlannedTransaction.for_account(Current.account).find(params[:id])
  end

  def planned_transaction_params
    permitted = params.expect(planned_transaction: [
      :description, :amount, :kind, :planned_for, :due_date, :importance, :category_id,
      :financial_account_id, :counterparty_financial_account_id, :financial_liability_id,
      :transaction_type, :source_selection, :destination_selection, :commits_plan_funds
    ])
    transaction_type = permitted.delete(:transaction_type)
    return permitted if transaction_type.blank?

    permitted[:kind] = nil
    permitted[:destination_selection] = nil unless transaction_type == "transfer"
    permitted
  end

  def apply_params
    params.fetch(:planned_transaction, {}).permit(:amount, :interest_amount, :entry_date, :description, :category_id, :financial_account_id, :counterparty_financial_account_id, :financial_liability_id)
  end

  def scoped_category(id)
    Category.for_account(Current.account).find_by(id: id) if id.present?
  end

  def scoped_asset(id)
    Financial::Asset.for_account(Current.account).find_by(id: id) if id.present?
  end

  def scoped_liability(id)
    Financial::Liability.for_account(Current.account).find_by(id: id) if id.present?
  end
end
