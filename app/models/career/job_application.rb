module Career
  class JobApplication < ApplicationRecord
    STATUSES = %w[saved researching applied screening interviewing technical_test offer rejected withdrawn ghosted].freeze

    belongs_to :account
    belongs_to :company,
      class_name: "Career::Company",
      foreign_key: :career_company_id,
      inverse_of: :job_applications

    has_many :events,
      class_name: "Career::Event",
      foreign_key: :career_job_application_id,
      dependent: :destroy,
      inverse_of: :job_application

    has_many :tasks, as: :taskable, class_name: "Projects::Task", dependent: :nullify
    has_many :documents, as: :documentable, class_name: "Projects::Doc", dependent: :nullify
    has_many :meetings, as: :meetingable, dependent: :nullify

    enum :priority, { low: 0, medium: 1, high: 2 }, prefix: true

    validates :role_title, presence: true
    validates :status, inclusion: { in: STATUSES }
    validates :currency, presence: true
    validates :fit_score, inclusion: { in: 0..100 }, allow_nil: true

    scope :for_account, ->(account) { where(account_id: account.id) }
    scope :by_status, ->(status) { status.present? ? where(status: status) : all }
    scope :by_priority, lambda { |priority|
      return all if priority.blank?

      key = priority.to_s
      priorities.key?(key) ? where(priority: priorities[key]) : all
    }
    scope :by_source, ->(source) { source.present? ? where(source: source) : all }
    scope :by_remote_type, ->(remote_type) { remote_type.present? ? where(remote_type: remote_type) : all }
    scope :recent_first, -> { order(created_at: :desc) }
    scope :needs_action, lambda {
      joins(:tasks).merge(Projects::Task.pending).distinct
    }

    def suggested_actions
      existing_keys = tasks.pending
        .where("metadata ->> 'source' = ?", "career_template")
        .pluck(Arel.sql("metadata ->> 'template_key'"))
        .compact

      TaskTemplates.for_status(status).reject { |template| existing_keys.include?(template.key) }
    end
  end
end
