class HabitLevelGoalsController < ApplicationController
  before_action :set_skill

  def create
    goal = @skill.level_goals.new(goal_params)
    goal.save!
    redirect_to @skill
  rescue ActiveRecord::RecordInvalid
    redirect_to @skill, alert: goal.errors.full_messages.to_sentence
  end

  def update
    goal = @skill.level_goals.find(params[:id])
    goal.update!(goal_params)
    redirect_to @skill
  rescue ActiveRecord::RecordInvalid
    redirect_to @skill, alert: goal.errors.full_messages.to_sentence
  end

  def destroy
    @skill.level_goals.find(params[:id]).destroy!
    redirect_to @skill
  end

  private

  def set_skill
    @skill = Habit::Skill.for_current.find(params[:habit_skill_id])
  end

  def goal_params
    attrs = params.require(:habit_level_goal).permit(:level, :description, :habit_id, :metric, :target, :achieved_on)
    attrs[:habit] = Habit.for_current.find(attrs.delete(:habit_id)) if attrs[:habit_id].present?
    attrs
  end
end
