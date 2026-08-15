class Financial::PlannedTransactionsController < ApplicationController
  before_action :set_planned_transaction, only: %i[update destroy]

  def index
    @planned_transactions = Financial::PlannedTransaction.for_account(Current.account)
    @planned_transactions = @planned_transactions.where(plan_id: params[:plan_id]) if params[:plan_id].present?
    @planned_transactions = @planned_transactions.unassigned if params[:unassigned] == "true" || params[:plan_id].blank?
    @planned_transactions = @planned_transactions.order(:planned_execution_date, :created_at)
    @plans = Financial::Plan.for_account(Current.account).where(lifecycle_status: %w[draft active]).chronological
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
    attributes = editable_planned_transaction_params
    if attributes && @planned_transaction.update(attributes)
      redirect_to finance_plan_path(@planned_transaction.plan), notice: "Planned transaction updated"
    else
      redirect_to finance_plan_path(@planned_transaction.plan), alert: @planned_transaction.errors.full_messages.to_sentence.presence || "Only pending transactions or applied plan commitments can be edited"
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

  def editable_planned_transaction_params
    return planned_transaction_params if @planned_transaction.execution_status == "pending"

    commitment_params = params.expect(planned_transaction: [ :commits_plan_funds ])
    commitment_params if @planned_transaction.execution_status == "applied" && commitment_params.key?(:commits_plan_funds)
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
