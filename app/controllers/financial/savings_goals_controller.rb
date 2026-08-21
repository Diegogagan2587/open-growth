class Financial::SavingsGoalsController < ApplicationController
  before_action :set_savings_goal, only: %i[show edit update destroy]
  before_action :load_categories, only: %i[new create edit update]

  def index
    @savings_goals = Financial::SavingsGoal.for_account(Current.account).includes(:category).order(:name)
  end

  def show
    @planned_transactions = @savings_goal.planned_transactions.includes(:plan).order(created_at: :desc)
  end

  def new
    @savings_goal = Financial::SavingsGoal.new
  end

  def create
    @savings_goal = Financial::SavingsGoal.new(savings_goal_params.merge(account: Current.account))
    return redirect_to(finance_savings_goal_path(@savings_goal), notice: "Savings goal created") if @savings_goal.save

    render :new, status: :unprocessable_entity
  end

  def edit; end

  def update
    return redirect_to(finance_savings_goal_path(@savings_goal), notice: "Savings goal updated") if @savings_goal.update(savings_goal_params)

    render :edit, status: :unprocessable_entity
  end

  def destroy
    @savings_goal.destroy!
    redirect_to finance_savings_goals_path, status: :see_other, notice: "Savings goal removed"
  end

  private

  def set_savings_goal
    @savings_goal = Financial::SavingsGoal.for_account(Current.account).find(params[:id])
  end

  def load_categories
    @categories = Category.for_account(Current.account).order(:name)
  end

  def savings_goal_params
    params.expect(financial_savings_goal: %i[name category_id description total_amount frequency notes])
  end
end
