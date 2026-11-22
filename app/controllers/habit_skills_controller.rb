class HabitSkillsController < ApplicationController
  before_action :set_skill, only: %i[show edit update]

  def index
    @skills = Habit::Skill.for_current.includes(:level_goals).order(:name)
  end

  def show
    @goals = @skill.level_goals.includes(:habit).order(:level, :id)
    @habits = Habit.for_current.active.select { |habit| habit.skill_on(Time.find_zone!(Current.user.time_zone).today)&.id == @skill.id }
    @goal = @skill.level_goals.new(level: @skill.level)
  end

  def new
    @skill = Habit::Skill.new
  end

  def create
    @skill = Habit::Skill.for_current.new(skill_params)
    if @skill.save
      redirect_to @skill
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @skill.update(skill_params)
      redirect_to @skill
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_skill
    @skill = Habit::Skill.for_current.find(params[:id])
  end

  def skill_params
    params.require(:habit_skill).permit(:name)
  end
end
