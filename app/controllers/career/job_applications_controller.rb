module Career
  class JobApplicationsController < ApplicationController
    before_action :set_job_application, only: [ :show, :edit, :update, :create_task, :create_suggested_task, :create_document, :create_meeting, :create_event ]

    def index
      @status = params[:status]
      @priority = params[:priority]
      @source = params[:source]
      @remote_type = params[:remote_type]
      @needs_action = ActiveModel::Type::Boolean.new.cast(params[:needs_action])

      @job_applications = Career::JobApplication.for_account(Current.account)
        .includes(:company)
        .by_status(@status)
        .by_priority(@priority)
        .by_source(@source)
        .by_remote_type(@remote_type)
      @job_applications = @job_applications.needs_action if @needs_action
      @job_applications = @job_applications.recent_first

      @sources = Career::JobApplication.for_account(Current.account).where.not(source: [ nil, "" ]).distinct.order(:source).pluck(:source)
      @remote_types = Career::JobApplication.for_account(Current.account).where.not(remote_type: [ nil, "" ]).distinct.order(:remote_type).pluck(:remote_type)
    end

    def show
      @tasks = @job_application.tasks.order(created_at: :desc)
      @documents = @job_application.documents.order(created_at: :desc)
      @meetings = @job_application.meetings.order(start_time: :desc)
      @events = @job_application.events.recent_first
      @suggested_actions = Career::JobApplications::NextActionsService.call(job_application: @job_application)
    end

    def new
      @job_application = Career::JobApplication.new(status: "saved", priority: :medium, currency: "USD", found_on: Date.current)
    end

    def create
      result = Career::JobApplications::CreateService.call(
        account: Current.account,
        user: Current.user,
        params: job_application_params.to_h.symbolize_keys
      )

      if result.success?
        redirect_to career_job_application_path(result.job_application), notice: "Job application created"
      else
        @job_application = result.job_application || Career::JobApplication.new
        flash.now[:alert] = result.errors.to_sentence
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      attrs = job_application_params.to_h.symbolize_keys

      if attrs[:company_name].present?
        company = Career::Company.for_account(Current.account)
          .where("LOWER(name) = ?", attrs[:company_name].to_s.strip.downcase)
          .first_or_create!(name: attrs[:company_name].to_s.strip)
        attrs[:career_company_id] = company.id
      end

      result = Career::JobApplications::UpdateStatusService.call(
        job_application: @job_application,
        actor: Current.user,
        params: attrs
      )

      if result.success?
        redirect_to career_job_application_path(@job_application), notice: "Job application updated"
      else
        flash.now[:alert] = result.errors.to_sentence
        render :edit, status: :unprocessable_entity
      end
    end

    def create_task
      task = Projects::Task.new(task_params)
      task.account = Current.account
      task.user = Current.user
      task.taskable = @job_application

      if task.save
        redirect_to career_job_application_path(@job_application), notice: "Task added"
      else
        redirect_to career_job_application_path(@job_application), alert: task.errors.full_messages.to_sentence
      end
    end

    def create_suggested_task
      template = Career::TaskTemplates.find(status: @job_application.status, key: params[:template_key])
      return redirect_to career_job_application_path(@job_application), alert: "Invalid suggested action" if template.nil?

      duplicate_exists = @job_application.tasks.pending.where("metadata ->> 'source' = ? AND metadata ->> 'template_key' = ?", "career_template", template.key).exists?
      return redirect_to career_job_application_path(@job_application), alert: "That suggested task is already pending" if duplicate_exists

      task = Projects::Task.new(
        title: template.title,
        description: template.description,
        status: "backlog",
        priority: template.priority,
        due_date: Date.current + template.due_in_days,
        metadata: {
          source: "career_template",
          template_key: template.key,
          generated_for_status: @job_application.status
        }
      )
      task.account = Current.account
      task.user = Current.user
      task.taskable = @job_application

      if task.save
        redirect_to career_job_application_path(@job_application), notice: "Suggested task added"
      else
        redirect_to career_job_application_path(@job_application), alert: task.errors.full_messages.to_sentence
      end
    end

    def create_document
      doc = Projects::Doc.new(document_params)
      doc.account = Current.account
      doc.documentable = @job_application

      if doc.save
        redirect_to career_job_application_path(@job_application), notice: "Document added"
      else
        redirect_to career_job_application_path(@job_application), alert: doc.errors.full_messages.to_sentence
      end
    end

    def create_meeting
      meeting = Meeting.new(meeting_params)
      meeting.account = Current.account
      meeting.meetingable = @job_application

      if meeting.save
        Career::Event.create!(
          account: Current.account,
          job_application: @job_application,
          event_type: "interview_scheduled",
          occurred_at: meeting.start_time,
          metadata: { title: meeting.title }
        )
        redirect_to career_job_application_path(@job_application), notice: "Meeting added"
      else
        redirect_to career_job_application_path(@job_application), alert: meeting.errors.full_messages.to_sentence
      end
    end

    def create_event
      event = @job_application.events.new(event_params)
      event.account = Current.account
      event.occurred_at ||= Time.current

      if event.save
        redirect_to career_job_application_path(@job_application), notice: "Event added"
      else
        redirect_to career_job_application_path(@job_application), alert: event.errors.full_messages.to_sentence
      end
    end

    private

    def set_job_application
      @job_application = Career::JobApplication.for_account(Current.account).find(params[:id])
    end

    def job_application_params
      params.require(:career_job_application).permit(
        :career_company_id,
        :company_name,
        :role_title,
        :job_url,
        :source,
        :status,
        :found_on,
        :applied_on,
        :salary_min,
        :salary_max,
        :currency,
        :remote_type,
        :location,
        :priority,
        :fit_score,
        :job_description,
        :notes
      )
    end

    def task_params
      params.require(:task).permit(:title, :description, :status, :priority, :due_date)
    end

    def document_params
      params.require(:doc).permit(:title, :content, :doc_type)
    end

    def meeting_params
      params.require(:meeting).permit(:title, :description, :location, :meeting_url, :start_time, :end_time)
    end

    def event_params
      params.require(:career_event).permit(:event_type, :occurred_at, metadata: {})
    end
  end
end
