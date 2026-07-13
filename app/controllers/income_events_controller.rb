class IncomeEventsController < ApplicationController
  before_action :set_income_event, only: [ :show, :edit, :update, :destroy, :receive, :apply_all, :loan_summary, :pay_liability ]
  before_action :set_budget_period, only: [ :index, :new, :create ]
  before_action :load_loan_route_collections, only: [ :new, :create, :edit, :update ]

  def index
    @income_events = if @budget_period
      @budget_period.income_events.includes(:budget_period).by_date
    else
      IncomeEvent.for_account(Current.account).includes(:budget_period).by_date
    end

    # Group by month/year for display
    @grouped_events = @income_events.group_by { |ie|
      ie.expected_date.beginning_of_month
    }.sort_by { |month, _| month }.reverse

    # Support month filter via params
    @selected_month = nil
    if params[:month].present?
      begin
        @selected_month = Date.parse(params[:month])
        @grouped_events = @grouped_events.select { |month, _| month == @selected_month.beginning_of_month }
      rescue ArgumentError
        # Invalid date format, ignore filter
        @selected_month = nil
      end
    end

    # Get available months for the selector
    @available_months = @income_events.map { |ie| ie.expected_date.beginning_of_month }.uniq.sort.reverse
  end

  def show
    @planned_expenses = @income_event.planned_expenses
      .includes(:income_event)
      .order(Arel.sql("COALESCE(planned_expenses.loan_installment_number, 2147483647) ASC"), :due_date, :created_at)
    @direct_expenses = @income_event.financial_entries
      .includes(:category)
      .where(planned_expense_id: nil, entry_type: %w[outflow liability_charge])
      .order(entry_date: :desc)
    @loan_payment_schedules = @income_event.loan_payment_schedules_ordered if @income_event.loan?
    @pending_liabilities = Financial::Liability.for_account(Current.account).active.select { |liability| liability.current_balance.positive? }
    @active_financial_accounts = Financial::Asset.for_account(Current.account).active.order(:name)
  end

  def loan_summary
    @loan_payment_schedules = @income_event.loan_payment_schedules_ordered
    @planned_expenses = @income_event.planned_expenses
      .includes(:income_event)
      .order(Arel.sql("COALESCE(planned_expenses.loan_installment_number, 2147483647) ASC"), :due_date, :created_at)
    @direct_expenses = @income_event.financial_entries
      .includes(:category)
      .where(planned_expense_id: nil, entry_type: %w[outflow liability_charge])
      .order(entry_date: :desc)
  end

  def new
    @income_event = @budget_period ? @budget_period.income_events.build : IncomeEvent.new
  end

  def create
    @income_event = IncomeEvent.for_account(Current.account).new(income_event_params)
    @income_event.account = Current.account
    @income_event.budget_period = @budget_period if @budget_period

    respond_to do |format|
      if @income_event.save
        format.html { redirect_to @income_event, notice: t("income_events.flash.created") }
        format.json { render :show, status: :created, location: @income_event }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @income_event.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    respond_to do |format|
      if @income_event.update(income_event_params)
        format.html { redirect_to @income_event, notice: t("income_events.flash.updated") }
        format.json { render :show, status: :ok, location: @income_event }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @income_event.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @income_event.destroy!

    respond_to do |format|
      format.html { redirect_to income_events_path, status: :see_other, notice: t("income_events.flash.destroyed") }
      format.json { head :no_content }
    end
  end

  def receive
    if request.patch? || request.put?
      if @income_event.update(receive_params.merge(status: "received"))
        if @income_event.loan?
          disbursement = Loans::DisbursementSyncService.call(@income_event)
          unless disbursement.success?
            flash.now[:alert] = disbursement.error_message
            render :receive, status: :unprocessable_entity
            return
          end
        end

        redirect_to @income_event, notice: t("income_events.flash.marked_received")
      else
        render :receive, status: :unprocessable_entity
      end
    end
  end

  def apply_all
    if @income_event.loan?
      result = Loans::ApplyService.call(@income_event)
      if result.success?
        redirect_to @income_event, notice: t("income_events.flash.applied_all")
      else
        redirect_to @income_event, alert: result.error_message
      end
      return
    end

    @income_event.apply_all!
    redirect_to @income_event, notice: t("income_events.flash.applied_all")
  end

  def pay_liability
    liability = Financial::Liability.for_account(Current.account).find_by(id: liability_payment_params[:financial_liability_id])
    source_account = Financial::Asset.for_account(Current.account).active.find_by(id: liability_payment_params[:financial_account_id])

    service = Financial::Liabilities::RecordPaymentService.call(
      liability: liability,
      source_account: source_account,
      amount: liability_payment_params[:amount],
      description: liability_payment_params[:description].presence || "Payment from #{@income_event.description}",
      entry_date: liability_payment_params[:entry_date],
      income_event: @income_event
    )

    if service.success?
      redirect_to @income_event, notice: "Liability payment applied"
    else
      redirect_to @income_event, alert: service.error_message
    end
  end

  private

  def set_income_event
    @income_event = IncomeEvent.for_account(Current.account).find(params[:id])
  end

  def set_budget_period
    @budget_period = BudgetPeriod.for_account(Current.account).find(params[:budget_period_id]) if params[:budget_period_id]
  end

  def income_event_params
    params.expect(income_event: [
      :expected_date,
      :expected_amount,
      :description,
      :status,
      :budget_period_id,
      :income_type,
      :loan_amount,
      :interest_rate,
      :number_of_payments,
      :payment_frequency,
      :payment_amount,
      :lender_name,
      :notes,
      :loan_liability_id,
      :destination_selection
    ])
  end

  def receive_params
    params.expect(income_event: [ :received_date, :received_amount ])
  end

  def liability_payment_params
    params.expect(income_event_liability_payment: [
      :financial_liability_id,
      :financial_account_id,
      :amount,
      :entry_date,
      :description
    ])
  end

  def load_loan_route_collections
    @financial_assets = Financial::Asset.for_account(Current.account).active.order(:name)
    @financial_liabilities = Financial::Liability.for_account(Current.account).active.order(:name)
  end
end
