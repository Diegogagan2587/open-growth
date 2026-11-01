module Projects
  class Task < ApplicationRecord
    STATUSES = %w[blocked backlog in_progress in_review done cancelled].freeze
    PRIORITIES = %w[low medium high].freeze

    belongs_to :project, optional: true
    belongs_to :taskable, polymorphic: true, optional: true
    belongs_to :account
    belongs_to :user, foreign_key: :owner_id
    has_many :dashboard_task_deferrals,
      as: :task,
      class_name: "Dashboard::TaskDeferral",
      dependent: :destroy
    has_many :project_docs, through: :project
    has_many :project_links, through: :project
    has_many :project_meetings, through: :project

    before_create :set_account_and_task_number

    validates :title, presence: true
    validates :task_number, uniqueness: { scope: :account_id, allow_nil: true }
    validates :status, inclusion: { in: STATUSES }
    validates :priority, inclusion: { in: PRIORITIES }
    scope :for_account, ->(account) { where(account_id: account.id) }
    scope :pending, -> { where(status: %w[blocked backlog in_progress in_review]) }
    scope :completed, -> { where(status: %w[done cancelled]) }
    scope :by_status, ->(status) { status.present? ? where(status: status) : all }
    scope :by_priority, ->(priority) { priority.present? ? where(priority: priority) : all }
    scope :by_project, ->(project_id) do
      if project_id.blank? || project_id == "all"
        all
      elsif project_id == "unassigned"
        where(project_id: nil)
      else
        where(project_id: project_id)
      end
    end
    scope :unassigned, -> { where(project_id: nil) }

    # Sort scopes
    scope :by_urgency, lambda {
      # Overdue first, then high priority, then soonest due date
      order(
        Arel.sql("CASE WHEN due_date < CURRENT_DATE THEN 0 ELSE 1 END"),
        Arel.sql("CASE WHEN priority = 'high' THEN 0 WHEN priority = 'medium' THEN 1 ELSE 2 END"),
        Arel.sql("CASE WHEN due_date IS NULL THEN 1 ELSE 0 END"),
        due_date: :asc,
        created_at: :desc
      )
    }
    scope :by_priority_desc, lambda {
      order(
        Arel.sql("CASE WHEN priority = 'high' THEN 0 WHEN priority = 'medium' THEN 1 ELSE 2 END"),
        Arel.sql("CASE WHEN due_date IS NULL THEN 1 ELSE 0 END"),
        due_date: :asc
      )
    }
    scope :by_due_date_asc, lambda {
      order(
        Arel.sql("CASE WHEN due_date < CURRENT_DATE THEN 0 ELSE 1 END"),
        Arel.sql("CASE WHEN due_date IS NULL THEN 1 ELSE 0 END"),
        due_date: :asc
      )
    }
    scope :newest_first, -> { order(created_at: :desc) }

    before_save :sync_completed_at, if: :will_save_change_to_status?

    def status_label
      I18n.t("tasks.status.#{status}", default: status)
    end

    def priority_label
      I18n.t("tasks.priority.#{priority}", default: priority)
    end

    def project_name
      project&.name || I18n.t("tasks.project.unassigned", default: "Unassigned")
    end

    def overdue?
      due_date.present? && due_date < Date.current
    end

    private

    def set_account_and_task_number
      self.account = Current.account if account.nil?
      generate_task_number
    end

    def generate_task_number
      return if task_number.present?

      current_acc = account || Current.account
      last_task = Task.where(account_id: current_acc.id).order(created_at: :desc).first
      next_number = if last_task
                      last_task.task_number.match(/\d+/)&.to_s&.to_i.to_i + 1
      else
                      1
      end
      self.task_number = "TASK-#{next_number}"
    end

    def sync_completed_at
      _, new_status = status_change_to_be_saved

      if completed_status?(new_status)
        self.completed_at ||= Time.current
      else
        self.completed_at = nil
      end
    end

    def completed_status?(value)
      %w[done cancelled].include?(value)
    end
  end
end
