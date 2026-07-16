class PlannedExpensesController < ApplicationController
  before_action :set_income_event
  before_action :set_planned_expense, only: [ :show, :edit, :update, :destroy, :apply, :move, :create_transaction ]
  before_action :load_route_collections, only: [ :new, :create, :edit, :update ]

  def index
    @planned_expenses = @income_event.planned_expenses_ordered.includes(
      :category,
      :financial_account,
      :counterparty_financial_account,
      :financial_liability,
      :expense_template,
      :financial_entry,
      :expense
    )
    @running_balance = @income_event.received_amount || @income_event.expected_amount
    @income_events = IncomeEvent.for_account(Current.account).order(:expected_date)
  end

  def show
    @income_events = IncomeEvent.for_account(Current.account).order(:expected_date)
    respond_to do |format|
      format.html
      format.json { render json: @planned_expense }
    end
  end

  def new
    @planned_expense = @income_event.planned_expenses.build
    @expense_templates = ExpenseTemplate.for_account(Current.account).includes(:category).all
    @income_events = ordered_income_events_for_reference(@planned_expense.due_date)
  end

  def create
    @planned_expense = @income_event.planned_expenses.build(planned_expense_params)
    @planned_expense.position ||= (@income_event.planned_expenses.maximum(:position) || 0) + 1

    respond_to do |format|
      success = false
      execution_error = nil

      ActiveRecord::Base.transaction do
        success = @planned_expense.save
        raise ActiveRecord::Rollback unless success

        if PlannedExpense.final_status?(@planned_expense.status)
          execution = PlannedExpenses::ExecuteService.call(
            planned_expense: @planned_expense,
            target_status: @planned_expense.status
          )
          unless execution.success?
            execution_error = execution.error_message
            @planned_expense.errors.add(:base, execution_error)
            raise ActiveRecord::Rollback
          end
        end
      end

      if success && execution_error.blank?

        format.html { redirect_to income_event_planned_expenses_path(@income_event), notice: t("planned_expenses.flash.created") }
        format.json { render :show, status: :created, location: [ @income_event, @planned_expense ] }
      else
        flash.now[:alert] = execution_error if execution_error.present?
        @expense_templates = ExpenseTemplate.for_account(Current.account).includes(:category).all
        @income_events = ordered_income_events_for_reference(@planned_expense.due_date)
        load_route_collections
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @planned_expense.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
    @expense_templates = ExpenseTemplate.for_account(Current.account).includes(:category).all
    @income_events = ordered_income_events_for_reference(@planned_expense.due_date)
  end

  def update
    old_income_event = @income_event
    new_income_event_id = planned_expense_params[:income_event_id]
    requested_status = planned_expense_params[:status]
    final_status_requested = PlannedExpense.final_status?(requested_status)
    should_execute_transaction = final_status_requested
    attrs = planned_expense_params
    attrs = attrs.except(:status) if final_status_requested

    respond_to do |format|
      if @planned_expense.update(attrs)
        if should_execute_transaction
          execution = PlannedExpenses::ExecuteService.call(
            planned_expense: @planned_expense,
            target_status: requested_status
          )
          unless execution.success?
            @planned_expense.errors.add(:base, execution.error_message)
            @expense_templates = ExpenseTemplate.for_account(Current.account).includes(:category).all
            @income_events = ordered_income_events_for_reference(@planned_expense.due_date)
            load_route_collections
            flash.now[:alert] = execution.error_message
            format.turbo_stream { render :edit, status: :unprocessable_entity }
            format.html { render :edit, status: :unprocessable_entity }
            format.json { render json: { error: execution.error_message }, status: :unprocessable_entity }
            return
          end
        end

        # If income_event_id changed, redirect to the new income event
        if new_income_event_id.present? && new_income_event_id.to_i != old_income_event.id
          new_income_event = IncomeEvent.for_account(Current.account).find(new_income_event_id)
          move_planned_expense_to!(@planned_expense, new_income_event)
          format.turbo_stream { redirect_to income_event_planned_expenses_path(new_income_event), notice: "Planned expense was successfully moved and updated." }
          format.html { redirect_to income_event_planned_expenses_path(new_income_event), notice: "Planned expense was successfully moved and updated." }
        else
          format.turbo_stream { redirect_to income_event_planned_expenses_path(@income_event), notice: t("planned_expenses.flash.updated") }
          format.html { redirect_to income_event_planned_expenses_path(@income_event), notice: t("planned_expenses.flash.updated") }
        end
        format.json { render :show, status: :ok, location: [ @income_event, @planned_expense ] }
      else
        @expense_templates = ExpenseTemplate.for_account(Current.account).includes(:category).all
        @income_events = ordered_income_events_for_reference(@planned_expense.due_date)
        load_route_collections
        format.turbo_stream { render :edit, status: :unprocessable_entity }
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @planned_expense.errors, status: :unprocessable_entity }
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    @planned_expense.errors.add(:base, e.record.errors.full_messages.to_sentence)
    @expense_templates = ExpenseTemplate.for_account(Current.account).includes(:category).all
    @income_events = ordered_income_events_for_reference(@planned_expense.due_date)
    load_route_collections
    respond_to do |format|
      format.turbo_stream { render :edit, status: :unprocessable_entity }
      format.html { render :edit, status: :unprocessable_entity }
      format.json { render json: @planned_expense.errors, status: :unprocessable_entity }
    end
  end

  def destroy
    @planned_expense.destroy!

    respond_to do |format|
      format.html { redirect_to income_event_planned_expenses_path(@income_event), status: :see_other, notice: "Planned expense was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def apply
    result = PlannedExpenses::ExecuteService.call(planned_expense: @planned_expense)

    if result.success?
      redirect_to income_event_planned_expenses_path(@income_event), notice: t("planned_expenses.flash.applied")
    else
      redirect_to income_event_planned_expenses_path(@income_event), alert: result.error_message
    end
  end

  def move
    target_income_event_id = params[:target_income_event_id]

    unless target_income_event_id.present?
      redirect_to income_event_planned_expenses_path(@income_event), alert: t("planned_expenses.alert_select_target")
      return
    end

    target_income_event = IncomeEvent.for_account(Current.account).find(target_income_event_id)

    if target_income_event.id == @income_event.id
      redirect_to income_event_planned_expenses_path(@income_event), alert: "The planned expense is already assigned to this income event."
      return
    end

    ActiveRecord::Base.transaction do
      move_planned_expense_to!(@planned_expense, target_income_event)
    end

    redirect_to income_event_planned_expenses_path(target_income_event), notice: t("planned_expenses.flash.moved_to", description: target_income_event.description)
  rescue ActiveRecord::RecordInvalid => e
    redirect_to income_event_planned_expenses_path(@income_event), alert: e.record.errors.full_messages.to_sentence
  rescue ActiveRecord::RecordNotUnique
    redirect_to income_event_planned_expenses_path(@income_event), alert: move_conflict_message(target_income_event)
  end

  def create_transaction
    result = PlannedExpenses::ExecuteService.call(
      planned_expense: @planned_expense,
      target_status: (@planned_expense.final_status? ? @planned_expense.status : nil)
    )

    if result.success?
      redirect_to income_event_planned_expense_path(@income_event, @planned_expense), notice: "Transaction created"
    else
      redirect_to income_event_planned_expense_path(@income_event, @planned_expense), alert: result.error_message
    end
  end

  private

  def set_income_event
    @income_event = IncomeEvent.for_account(Current.account).find(params[:income_event_id])
  end

  def set_planned_expense
    @planned_expense = @income_event.planned_expenses.find(params[:id])
  end

  def planned_expense_params
    params.expect(planned_expense: [
      :category_id,
      :description,
      :amount,
      :due_date,
      :notes,
      :status,
      :position,
      :expense_template_id,
      :income_event_id,
      :source_selection,
      :destination_selection
    ])
  end

  def load_route_collections
    @financial_accounts = Financial::Asset.for_account(Current.account).order(:name)
    @financial_liabilities = Financial::Liability.for_account(Current.account).order(:name)
  end

  def ordered_income_events_for_reference(reference_date)
    events = IncomeEvent.for_account(Current.account).to_a
    return events.sort_by(&:expected_date) if reference_date.blank?

    same_month, others = events.partition do |event|
      event.expected_date.year == reference_date.year && event.expected_date.month == reference_date.month
    end
    on_or_before, after = same_month.partition { |event| event.expected_date <= reference_date }

    prioritized_same_month = on_or_before.sort_by(&:expected_date).reverse + after.sort_by(&:expected_date)
    prioritized_same_month + others.sort_by(&:expected_date).reverse
  end

  def move_planned_expense_to!(planned_expense, target_income_event)
    ensure_unique_installment_for!(planned_expense, target_income_event)

    planned_expense.update!(income_event_id: target_income_event.id)

    if planned_expense.position.nil?
      planned_expense.update!(position: (target_income_event.planned_expenses.maximum(:position) || 0) + 1)
    end

    if planned_expense.expense.present?
      planned_expense.expense.update!(
        income_event_id: target_income_event.id,
        budget_period_id: target_income_event.budget_period_id
      )
    end

    return unless planned_expense.financial_entry.present?

    planned_expense.financial_entry.update!(income_event_id: target_income_event.id)
  end

  def ensure_unique_installment_for!(planned_expense, target_income_event)
    return if planned_expense.loan_installment_number.blank?
    return if planned_expense.origin_income_event_id.present?

    conflict_exists = target_income_event.planned_expenses
      .where(loan_installment_number: planned_expense.loan_installment_number)
      .where.not(id: planned_expense.id)
      .exists?

    return unless conflict_exists

    planned_expense.errors.add(:loan_installment_number, :taken, message: move_conflict_message(target_income_event))
    raise ActiveRecord::RecordInvalid.new(planned_expense)
  end

  def move_conflict_message(target_income_event)
    "Cannot move this planned expense because installment ##{@planned_expense.loan_installment_number} already exists in #{target_income_event.description}."
  end
end
