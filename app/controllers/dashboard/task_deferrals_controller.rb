# frozen_string_literal: true

class Dashboard::TaskDeferralsController < ApplicationController
  def create
    task = case params[:task_type]
    when "recurring"
      RecurringTask.for_account(Current.account).find(params[:task_id])
    when "project"
      Projects::Task.for_account(Current.account).find(params[:task_id])
    else
      raise ActiveRecord::RecordNotFound
    end

    TaskDeferral.defer!(task:, account: Current.account, user: Current.user)
    redirect_to root_path
  end
end
