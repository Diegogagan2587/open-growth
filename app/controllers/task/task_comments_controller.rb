module Task
  class TaskCommentsController < ApplicationController
    def create
      task = Projects::Task.for_account(Current.account).find(params[:task_id])
      comment = task.comments.build(body: params.require(:task_comment).permit(:body).fetch(:body))
      comment.user = Current.user

      if comment.save
        redirect_to task_task_path(task, return_to: params[:return_to]), notice: "Comment added."
      else
        redirect_to task_task_path(task, return_to: params[:return_to]), alert: "Comment can't be blank."
      end
    end
  end
end
