class HabitCheckInsController < ApplicationController
  before_action :set_habit

  def create
    save_check_in
  end

  def update
    save_check_in
  end

  def destroy
    @habit.check_ins.find(params[:id]).destroy!
    redirect_to @habit
  end

  private

  def set_habit
    @habit = Habit.for_current.find(params[:habit_id])
  end

  def save_check_in
    date = Date.iso8601(params.require(:habit_check_in).require(:on_date))
    entry = @habit.check_ins.find_or_initialize_by(on_date: date)
    entry.transaction do
      entry.assign_attributes(params.require(:habit_check_in).permit(:done, :amount))
      entry.save!
      if @habit.kind == "exercise"
        entry.sets.destroy_all
        Array(params.dig(:habit_check_in, :sets)).each_with_index do |set, index|
          next if set[:reps].blank?
          entry.sets.create!(position: index + 1, reps: set[:reps], weight: set[:weight].presence)
        end
      end
    end
    redirect_to params[:return_to] == "dashboard" ? root_path : habit_path(@habit), notice: t("habits.logged")
  rescue ArgumentError, ActiveRecord::RecordInvalid
    redirect_to habit_path(@habit), alert: t("habits.invalid_check_in")
  end
end
