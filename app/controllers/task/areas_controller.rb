# frozen_string_literal: true

module Task
  class AreasController < ApplicationController
    before_action :set_task_area, only: [ :show, :edit, :update, :destroy ]

    def index
      @task_areas = Projects::Task::Area.for_account(Current.account).order(:name)
    end

    def show
    end

    def new
      @task_area = Projects::Task::Area.new
    end

    def create
      @task_area = Projects::Task::Area.for_account(Current.account).new(task_area_params)
      @task_area.account = Current.account

      if @task_area.save
        redirect_to task_areas_path, notice: t("task.areas.flash.created")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @task_area.update(task_area_params)
        redirect_to task_areas_path, notice: t("task.areas.flash.updated")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @task_area.destroy!
      redirect_to task_areas_path, status: :see_other, notice: t("task.areas.flash.destroyed")
    end

    private

    def set_task_area
      @task_area = Projects::Task::Area.for_account(Current.account).find(params[:id])
    end

    def task_area_params
      params.require(:task_area).permit(:name)
    end
  end
end
