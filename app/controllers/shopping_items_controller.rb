class ShoppingItemsController < ApplicationController
  before_action :set_shopping_item, only: [ :show, :edit, :update, :destroy, :mark_as_purchased, :convert_to_planned_expense, :convert_to_expense, :link_to_planned_expense ]

  def index
    @status_filter = params[:status] || "pending"
    @shopping_items = ShoppingItem.for_account(Current.account).includes(:category)

    if @status_filter == "pending"
      @shopping_items = @shopping_items.pending
    elsif @status_filter == "purchased"
      @shopping_items = @shopping_items.purchased
    end

    @grouped_shopping_items = build_grouped_shopping_items(@shopping_items)
  end

  def show
    @income_events = Financial::Plan.for_account(Current.account).chronological
    @budget_periods = BudgetPeriod.for_account(Current.account).order(start_date: :desc)
    @planned_expenses = Financial::PlannedTransaction.for_account(Current.account).where(shopping_item_id: nil).includes(:plan, :category).order(created_at: :desc)
  end

  def new
    @shopping_item = ShoppingItem.new
    @categories = Category.for_account(Current.account).order(:name)
  end

  def create
    @shopping_item = ShoppingItem.for_account(Current.account).new(shopping_item_params)
    @shopping_item.account = Current.account

    respond_to do |format|
      if @shopping_item.save
        format.html { redirect_to @shopping_item, notice: t("shopping_items.flash.created") }
        format.json { render :show, status: :created, location: @shopping_item }
      else
        @categories = Category.for_account(Current.account).order(:name)
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @shopping_item.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
    @categories = Category.for_account(Current.account).order(:name)
  end

  def update
    respond_to do |format|
      if @shopping_item.update(shopping_item_params)
        format.html { redirect_to @shopping_item, notice: t("shopping_items.flash.updated") }
        format.json { render :show, status: :ok, location: @shopping_item }
      else
        @categories = Category.for_account(Current.account).order(:name)
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @shopping_item.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @shopping_item.destroy!

    respond_to do |format|
      format.html { redirect_to shopping_items_path, status: :see_other, notice: "Shopping item was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def mark_as_purchased
    @shopping_item.mark_as_purchased!
    redirect_to shopping_items_path, notice: t("shopping_items.flash.marked_purchased")
  end

  def convert_to_planned_expense
    if request.post?
      income_event_id = params[:income_event_id]
      unless income_event_id.present?
        @income_events = Financial::Plan.for_account(Current.account).chronological
        flash.now[:alert] = t("shopping_items.alert_select_income_event")
        render :convert_to_planned_expense, status: :unprocessable_entity
        return
      end

      plan = Financial::Plan.for_account(Current.account).find(income_event_id)
      planned_expense = @shopping_item.convert_to_planned_expense(plan)

      if planned_expense
        redirect_to finance_plan_path(plan), notice: t("shopping_items.flash.converted_to_planned_expense")
      else
        redirect_to @shopping_item, alert: t("shopping_items.alert_estimated_required")
      end
    else
      @income_events = Financial::Plan.for_account(Current.account).chronological
    end
  end

  def convert_to_expense
    @financial_accounts = Financial::Asset.for_account(Current.account).active.order(:name)
    if request.post?
      budget_period_id = params[:budget_period_id]
      unless budget_period_id.present?
        @budget_periods = BudgetPeriod.for_account(Current.account).order(start_date: :desc)
        flash.now[:alert] = t("shopping_items.alert_select_budget_period")
        render :convert_to_expense, status: :unprocessable_entity
        return
      end

      budget_period = BudgetPeriod.for_account(Current.account).find(budget_period_id)
      financial_account = Financial::Asset.for_account(Current.account).active.find_by(id: params[:financial_account_id])
      expense = @shopping_item.convert_to_expense(budget_period, financial_account: financial_account)

      if expense
        redirect_to finance_transactions_path(transaction_type: "expense"), notice: "Shopping item converted to expense."
      else
        redirect_to @shopping_item, alert: t("shopping_items.alert_estimated_required")
      end
    else
      @budget_periods = BudgetPeriod.for_account(Current.account).order(start_date: :desc)
    end
  end

  def link_to_planned_expense
    if request.patch?
      planned_expense_id = params[:planned_expense_id]
      unless planned_expense_id.present?
        @planned_expenses = Financial::PlannedTransaction.for_account(Current.account).where(shopping_item_id: nil).includes(:plan, :category).order(created_at: :desc)
        flash.now[:alert] = t("shopping_items.alert_select_planned_expense")
        render :link_to_planned_expense, status: :unprocessable_entity
        return
      end

      planned_expense = Financial::PlannedTransaction.for_account(Current.account).find(planned_expense_id)
      @shopping_item.link_to_planned_expense(planned_expense)
      redirect_to @shopping_item, notice: t("shopping_items.flash.linked")
    else
      @planned_expenses = Financial::PlannedTransaction.for_account(Current.account).where(shopping_item_id: nil).includes(:plan, :category).order(created_at: :desc)
    end
  end

  private

  def set_shopping_item
    @shopping_item = ShoppingItem.for_account(Current.account).find(params[:id])
  end

  def shopping_item_params
    params.expect(shopping_item: [ :name, :status, :item_type, :quantity, :estimated_amount, :category_id, :frequency, :notes ])
  end

  def build_grouped_shopping_items(items)
    grouped = items.group_by(&:category_id)
    category_ids = grouped.keys.compact
    categories_ordered = Category.where(id: category_ids).order(:name)
    result = categories_ordered.map { |cat| [ cat, grouped[cat.id].sort_by(&:name) ] }
    result << [ nil, grouped[nil].sort_by(&:name) ] if grouped.key?(nil)
    result
  end
end
