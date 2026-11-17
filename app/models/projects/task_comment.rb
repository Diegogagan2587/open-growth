module Projects
  class TaskComment < ApplicationRecord
    belongs_to :task, class_name: "Projects::Task"
    belongs_to :user

    validates :body, presence: true
  end
end
