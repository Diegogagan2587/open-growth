# frozen_string_literal: true

module Task
  class RecurringTasksController < ApplicationController
    before_action :set_recurring_task, only: [ :show, :edit, :update, :destroy, :mark_done ]
    before_action :set_task_areas, only: [ :index, :new, :create, :edit, :update ]

    def index
      @recurring_tasks = RecurringTask.for_account(Current.account).pending.by_next_due
      @recurring_tasks = @recurring_tasks.where(task_area_id: params[:task_area_id]) if params[:task_area_id].present?
      @projects = Projects::Project.for_account(Current.account).order(:name)
      @task_status_options = Projects::Task::STATUSES
      @task_priority_options = Projects::Task::PRIORITIES

      # Get all standalone tasks and filter by project/priority
      all_tasks = Projects::Task.for_account(Current.account)
      all_tasks = all_tasks.by_project(params[:project_id])
      all_tasks = all_tasks.by_priority(params[:priority])

      # Apply sort order (default: urgency)
      sort_option = params[:sort]&.to_sym || :urgency
      case sort_option
      when :priority
        all_tasks = all_tasks.by_priority_desc
      when :due_date
        all_tasks = all_tasks.by_due_date_asc
      when :newest
        all_tasks = all_tasks.newest_first
      else
        # Default to urgency
        all_tasks = all_tasks.by_urgency
      end

      # Split into pending and completed
      @pending_tasks = all_tasks.where(status: %w[blocked backlog in_progress in_review])
      @completed_tasks = all_tasks.where(status: %w[done cancelled])

      # Pass sort state to view
      @current_sort = sort_option
      @sort_options = [ "urgency", "priority", "due_date", "newest" ]
    end

    def show
      @return_to_dashboard = params[:return_to] == "dashboard"
    end

    def new
      @recurring_task = RecurringTask.new(next_due_date: Date.current)
      @recurring_task.task_area_id = params[:task_area_id] if params[:task_area_id].present?
    end

    def create
      @recurring_task = RecurringTask.for_account(Current.account).new(recurring_task_params)
      @recurring_task.account = Current.account

      if @recurring_task.save
        redirect_to task_root_path(task_area_id: params[:task_area_id]), notice: t("task.recurring_tasks.flash.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @recurring_task.update(recurring_task_params)
        redirect_to task_root_path(task_area_id: params[:task_area_id]), notice: t("task.recurring_tasks.flash.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @recurring_task.destroy!
      redirect_to task_root_path(task_area_id: params[:task_area_id]), status: :see_other, notice: t("task.recurring_tasks.flash.destroyed")
    end

    def mark_done
      @recurring_task.mark_done!
      redirect_to task_root_path(task_area_id: params[:task_area_id]), notice: t("task.recurring_tasks.flash.mark_done")
    end

    private

    def set_recurring_task
      @recurring_task = RecurringTask.for_account(Current.account).find(params[:id])
    end

    def set_task_areas
      @task_areas = TaskArea.for_account(Current.account).order(:name)
    end

    def recurring_task_params
      params.require(:recurring_task).permit(:name, :task_area_id, :recurrence, :next_due_date, :notes)
    end
  end
end
