class Financial::ExpensesController < ApplicationController
  include Financial::AccountReferenceFiltering

  EXPENSE_ENTRY_TYPES = %w[outflow liability_charge ].freeze

  before_action :set_budget_period, only: [ :new, :create ]
  before_action :set_income_event_context, only: [ :quick_new, :quick_create ]
  before_action :set_expense, only: %i[ show edit update destroy ]
  before_action :load_finance_account_collections, only: [ :new, :create, :edit, :update, :quick_new, :quick_create ]
  before_action :load_account_filter_options, only: [ :index ]


  def index
    @expenses = Financial::Entry.for_account(Current.account).where(entry_type: EXPENSE_ENTRY_TYPES)
    @expenses = apply_account_ref_filter(@expenses)
    @expenses = @expenses.where("entry_date >= ?", params[:date_from]) if params[:date_from].present?
    @expenses = @expenses.where("entry_date <= ?", params[:date_to])   if params[:date_to].present?
    @expenses = @expenses.where(category_id: params[:category_id]) if params[:category_id].present?
    @expenses = @expenses.where("description ILIKE ?", "%#{params[:q]}%") if params[:q].present?
    @selected_account_ref = selected_account_ref
    @categories = Category.for_account(Current.account).order(:name)
  end

  # GET /expenses or /expenses.json
  def new
    @expense = @budget_period ? @budget_period.expenses.build : Expense.for_account(Current.account).new
    @expense.account = Current.account unless @expense.account
    # Load income events for dynamic filtering
    @income_events = IncomeEvent.for_account(Current.account).order(expected_date: :desc)
  end

  # GET /expenses/1 or /expenses/1.json
  def show
  end

  # GET /income_events/:income_event_id/direct_expenses/new
  def quick_new
    @expense = Expense.for_account(Current.account).new(
      income_event: @income_event,
      budget_period: @income_event.budget_period,
      date: Date.current
    )
    load_quick_form_collections
  end

  # GET /expenses/1/edit
  def edit
    # Load income events for dynamic filtering
    @income_events = IncomeEvent.for_account(Current.account).order(expected_date: :desc)
  end

  # POST /expenses or /expenses.json
  def create
    @expense = Expense.for_account(Current.account).new(expense_params)
    @expense.account = Current.account

    # Auto-suggest budget_period from income_event if income_event is set and budget_period is not
    if @expense.income_event_id.present? && @expense.budget_period_id.blank?
      income_event = IncomeEvent.for_account(Current.account).find(@expense.income_event_id)
      @expense.budget_period_id = income_event.budget_period_id if income_event.budget_period_id
    end

    respond_to do |format|
      result = Expenses::RecordExecutionService.call(
        expense: @expense,
        source_selection: expense_params[:source_selection],
        destination_selection: expense_params[:destination_selection],
        financial_account_id: expense_params[:financial_account_id],
        financial_liability_id: expense_params[:financial_liability_id]
      )

      if result.success?
        target = @expense.budget_period || finance_financial_entries_path
        format.html { redirect_to target, notice: t("expenses.flash.created") }
        format.json { render json: { id: result.entry.id }, status: :created, location: finance_financial_entry_path(result.entry) }
      else
        # Load income events for form re-render on error
        @income_events = IncomeEvent.for_account(Current.account).order(expected_date: :desc)
        flash.now[:alert] = result.error_message
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @expense.errors, status: :unprocessable_entity }
      end
    end
  end

  # POST /income_events/:income_event_id/direct_expenses
  def quick_create
    @expense = Expense.for_account(Current.account).new(quick_expense_params)
    @expense.account = Current.account
    @expense.income_event = @income_event
    @expense.budget_period ||= @income_event.budget_period

    result = Expenses::RecordExecutionService.call(
      expense: @expense,
      source_selection: quick_expense_params[:source_selection],
      destination_selection: quick_expense_params[:destination_selection],
      financial_account_id: quick_expense_params[:financial_account_id],
      financial_liability_id: quick_expense_params[:financial_liability_id]
    )

    if result.success?
      redirect_to @income_event, notice: t("expenses.flash.quick_created")
    else
      load_quick_form_collections
      flash.now[:alert] = result.error_message
      render :quick_new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /expenses/1 or /expenses/1.json
  def update
    new_income_event_id = expense_params[:income_event_id]
    attrs = mapped_entry_attributes(expense_params)

    ActiveRecord::Base.transaction do
      legacy_expense = Expense.for_account(Current.account).find_by(id: params[:id])
      target_entry = legacy_expense&.financial_entry || @expense
      target_entry.update!(attrs)
      @expense = target_entry

      if @expense.planned_expense.present? && new_income_event_id.present?
        @expense.planned_expense.update!(income_event_id: new_income_event_id)
      end
    end

    respond_to do |format|
      format.html { redirect_to expense_path(params[:id]), notice: t("expenses.flash.updated") }
      format.json { render :show, status: :ok, location: expense_path(params[:id]) }
    end
  rescue ActiveRecord::RecordInvalid => e
    @expense.errors.add(:base, e.record.errors.full_messages.to_sentence) unless e.record == @expense
    @income_events = IncomeEvent.for_account(Current.account).order(expected_date: :desc)
    load_finance_account_collections
    respond_to do |format|
      format.html { render :edit, status: :unprocessable_entity }
      format.json { render json: @expense.errors, status: :unprocessable_entity }
    end
  end

  # DELETE /expenses/1 or /expenses/1.json
  def destroy
    legacy_expense = Expense.for_account(Current.account).find_by(id: params[:id])
    @expense.destroy!
    legacy_expense&.destroy! if legacy_expense.present?

    respond_to do |format|
      format.html { redirect_to expenses_path, status: :see_other, notice: t("expenses.flash.destroyed") }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_expense
      id = params.expect(:id)
      scope = Financial::Entry.for_account(Current.account)
        .where(entry_type: EXPENSE_ENTRY_TYPES)
      legacy_expense = Expense.for_account(Current.account).find_by(id: id)
      @expense = legacy_expense&.financial_entry || scope.find_by(expense_id: id) || scope.find_by(id: id)
      raise ActiveRecord::RecordNotFound if @expense.blank?
    end

    # Only allow a list of trusted parameters through.
    def expense_params
      params.expect(expense: [ :date, :amount, :description, :category_id, :budget_period_id, :income_event_id, :financial_account_id, :financial_liability_id, :source_selection, :destination_selection ])
    end

    def set_budget_period
      if params[:budget_period_id]
        @budget_period = BudgetPeriod.for_account(Current.account).find(params[:budget_period_id])
      end
    end

    def set_income_event_context
      @income_event = IncomeEvent.for_account(Current.account).find(params[:income_event_id])
    end

    def quick_expense_params
      params.expect(expense: [ :date, :amount, :description, :category_id, :budget_period_id, :financial_account_id, :financial_liability_id, :source_selection, :destination_selection ])
    end

    def load_quick_form_collections
      @categories = Category.for_account(Current.account).order(:name)
      @budget_periods = BudgetPeriod.for_account(Current.account).order(start_date: :desc)
    end

    def load_finance_account_collections
      @financial_accounts = Financial::Asset.for_account(Current.account).active.order(:name)
      @financial_liabilities = Financial::Liability.for_account(Current.account).active.order(:name)
    end

    def mapped_entry_attributes(params_hash)
      source = params_hash[:source_selection].presence
      destination = params_hash[:destination_selection].presence

      if source.blank?
        source = "asset:#{params_hash[:financial_account_id]}" if params_hash[:financial_account_id].present?
        source = "liability:#{params_hash[:financial_liability_id]}" if params_hash[:financial_liability_id].present?
      end

      source_kind, source_id = source.to_s.split(":", 2)
      destination_kind, destination_id = destination.to_s.split(":", 2)

      attrs = {
        entry_date: params_hash[:date],
        amount: params_hash[:amount],
        description: params_hash[:description],
        category_id: params_hash[:category_id],
        budget_period_id: params_hash[:budget_period_id],
        income_event_id: params_hash[:income_event_id],
        counterparty_financial_account_id: nil,
        counterparty_financial_liability_id: nil
      }

      if source_kind == "liability"
        attrs.merge!(
          entry_type: "liability_charge",
          financial_account_id: nil,
          financial_liability_id: source_id
        )
      elsif destination_kind == "asset"
        attrs.merge!(
          entry_type: "transfer",
          financial_account_id: source_id,
          counterparty_financial_account_id: destination_id,
          financial_liability_id: nil
        )
      elsif destination_kind == "liability"
        attrs.merge!(
          entry_type: "liability_payment",
          financial_account_id: source_id,
          financial_liability_id: destination_id
        )
      else
        attrs.merge!(
          entry_type: "outflow",
          financial_account_id: source_id,
          financial_liability_id: nil
        )
      end

      attrs
    end
end
