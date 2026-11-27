module Projects
  class TasksController < ApplicationController
    before_action :set_project
    before_action :set_task, only: [ :show, :edit, :update, :destroy ]
    before_action :ensure_task_access, only: [ :show, :edit, :update, :destroy ]
    before_action :set_account_users, only: [ :new, :create, :edit, :update ]

    def index
      @tasks = @project.tasks.order(created_at: :desc)
    end

    def show
    end

    def new
      @task = @project.tasks.build
      @task.user = Current.user
    end

    def create
      @task = @project.tasks.build(task_params)
      @task.user = Current.user if @task.owner_id.blank?
      @task.account = Current.account

      if @task.save
        redirect_to project_task_path(@project, @task), notice: t("tasks.flash.created")
      else
        Rails.logger.error("Task validation errors: #{@task.errors.full_messages}")
        render :new
      end
    end

    def edit
    end

    def update
      if @task.update(task_params)
        respond_to do |format|
          format.html { redirect_to project_task_path(@project, @task), notice: t("tasks.flash.updated") }
          format.json { render json: { id: @task.id, status: @task.status }, status: :ok }
        end
      else
        respond_to do |format|
          format.html { render :edit }
          format.json { render json: { errors: @task.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    end

    def destroy
      @task.destroy
      redirect_to project_tasks_url(@project), notice: t("tasks.flash.destroyed")
    end

    private

    def set_project
      @project = Project.for_account(Current.account).find(params[:project_id])
    rescue ActiveRecord::RecordNotFound
      redirect_to projects_url
    end

    def set_task
      @task = @project.tasks.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to project_tasks_url(@project)
    end

    def ensure_task_access
      unless @task && @task.account_id == Current.account.id
        redirect_to project_tasks_url(@project)
      end
    end

    def task_params
      params.require(:task).permit(:title, :description, :status, :priority, :due_date, :owner_id)
    end

    def set_account_users
      @account_users = Current.account.users.order(:name)
    end
  end
end
