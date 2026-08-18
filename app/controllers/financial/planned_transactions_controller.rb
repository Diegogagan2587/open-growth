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
    requested_plan_id = planned_transaction_params[:plan_id].presence
    plan = Financial::Plan.for_account(Current.account).find_by(id: requested_plan_id)
    raise ActiveRecord::RecordNotFound, "Plan not found" if requested_plan_id && plan.nil?
    transaction = build_planned_transaction(plan)
    if transaction.save
      redirect_to plan ? finance_plan_path(plan) : finance_planned_transactions_path, notice: "Planned transaction added"
    else
      redirect_back fallback_location: finance_planned_transactions_path, alert: transaction.errors.full_messages.to_sentence
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
    if @planned_transaction.execution_status == "pending" && @planned_transaction.destroy
      redirect_back fallback_location: finance_planned_transactions_path, status: :see_other, notice: "Planned transaction removed"
    else
      redirect_back fallback_location: finance_planned_transactions_path, alert: "Only pending transactions can be removed"
    end
  end

  private

  def set_planned_transaction
    @planned_transaction = Financial::PlannedTransaction.for_account(Current.account).find(params[:id])
  end

  def planned_transaction_params
    params.expect(planned_transaction: [
      :plan_id, :description, :planned_amount, :amount, :kind, :planned_execution_date, :planned_for,
      :due_date, :importance, :category_id, :source_account_id, :destination_account_id,
      :budget_consuming, :recurring_transaction_id, :commits_plan_funds
    ]).tap do |permitted|
      permitted[:planned_amount] ||= permitted.delete(:amount)
      permitted[:planned_execution_date] ||= permitted.delete(:planned_for)
    end
  end

  def editable_planned_transaction_params
    return planned_transaction_params if @planned_transaction.execution_status == "pending"

    commitment_params = params.expect(planned_transaction: [ :commits_plan_funds ])
    commitment_params if @planned_transaction.execution_status == "applied" && commitment_params.key?(:commits_plan_funds)
  end

  def build_planned_transaction(plan)
    recurring_id = planned_transaction_params[:recurring_transaction_id].presence
    return Financial::PlannedTransaction.new(planned_transaction_params.merge(account: Current.account, plan: plan)) unless recurring_id

    recurring = Financial::RecurringTransaction.for_account(Current.account).active.find(recurring_id)
    recurring.build_occurrence(
      plan: plan,
      planned_execution_date: planned_transaction_params[:planned_execution_date]
    )
  end

  def move_if_requested(attributes)
    return unless attributes.key?(:plan_id)

    target_id = attributes.delete(:plan_id)
    return if target_id.to_s == @planned_transaction.plan_id.to_s

    target = Financial::Plan.for_account(Current.account).find_by(id: target_id.presence)
    return Financial::PlannedTransactions::MoveService::Result.new(success?: false, error_message: "Plan not found", planned_transaction: @planned_transaction) if target_id.present? && target.nil?

    Financial::PlannedTransactions::MoveService.call(planned_transaction: @planned_transaction, target_plan: target)
  end
end
