# frozen_string_literal: true

module Task
  class TasksController < ApplicationController
    before_action :set_task, only: [ :edit, :update ]
    before_action :set_projects, only: [ :edit, :update ]

    def edit
      respond_to do |format|
        format.html { render layout: request.xhr? ? false : "application" }
      end
    end

    def update
      old_status = @task.status
      if @task.update(task_params)
        return redirect_to(root_path, notice: t("tasks.flash.updated")) if return_to_dashboard?

        respond_to do |format|
          format.html { redirect_to task_root_path(task_filter_params), notice: t("tasks.flash.updated") }
          format.turbo_stream do
            if tabs_differ?(old_status, @task.status)
              # Task moved between Pending and Completed tabs
              target_tab = get_target_tab(@task.status)
                empty_id = target_tab == "completed_tasks" ? "completed_empty" : "pending_empty"
                streams = [
                  turbo_stream.remove(helpers.dom_id(@task)),
                  turbo_stream.prepend(
                    target_tab,
                    partial: "task/tasks/task_card",
                    locals: { task: @task, filter_params: task_filter_params }
                  ),
                  turbo_stream.replace(empty_id, "")
                ]
                render turbo_stream: streams
            else
              render turbo_stream: turbo_stream.replace(
                helpers.dom_id(@task),
                partial: "task/tasks/task_card",
                locals: { task: @task, filter_params: task_filter_params }
              )
            end
          end
        end
      else
        respond_to do |format|
          format.html { render :edit, status: :unprocessable_entity }
          format.turbo_stream { head :unprocessable_entity }
        end
      end
    end

    private

    def set_task
      @task = Projects::Task.for_account(Current.account).find(params[:id])
    end

    def set_projects
      @projects = Projects::Project.for_account(Current.account).order(:name)
    end

    def task_params
      params.require(:task).permit(:title, :description, :status, :priority, :due_date, :project_id)
    end

    def task_filter_params
      filters = params.permit(:project_id, :status, :priority).to_h.symbolize_keys.compact_blank
      filters[:return_to] = "dashboard" if return_to_dashboard?
      filters
    end

    def return_to_dashboard?
      params[:return_to] == "dashboard"
    end

    def tabs_differ?(old_status, new_status)
      pending_statuses = %w[blocked backlog in_progress in_review]

      old_is_pending = pending_statuses.include?(old_status)
      new_is_pending = pending_statuses.include?(new_status)

      old_is_pending != new_is_pending
    end

    def get_target_tab(status)
      completed_statuses = %w[done cancelled]
      completed_statuses.include?(status) ? "completed_tasks" : "pending_tasks"
    end
  end
end
