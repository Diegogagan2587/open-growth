class Projects::Task::Comment < ApplicationRecord
  self.table_name = "task_comments"

  belongs_to :task, class_name: "Projects::Task"
  belongs_to :user

  validates :body, presence: true
end
