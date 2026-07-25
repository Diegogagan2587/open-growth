# frozen_string_literal: true

class Dashboard::PendingTaskRowComponent < ViewComponent::Base
  def initialize(task:)
    @task = task
  end

  attr_reader :task

  def recurring?
    task.is_a?(RecurringTask)
  end

  def title
    recurring? ? task.name : task.title
  end

  def due_date
    recurring? ? task.next_due_date : task.due_date
  end

  def context_label
    return [ I18n.t("task.recurring_tasks.model_name"), task.task_area&.name ].compact.join(" · ") if recurring?
    return task.project.name if task.project.present?
    return task.taskable_type.demodulize.titleize if task.taskable_type.present?

    I18n.t("tasks.project.unassigned", default: "Unassigned")
  end

  def detail_path
    if recurring?
      helpers.task_recurring_task_path(task, return_to: "dashboard")
    else
      helpers.edit_task_task_path(task, return_to: "dashboard")
    end
  end

  def completion_path
    if recurring?
      helpers.mark_done_task_recurring_task_path(task, return_to: "dashboard")
    else
      helpers.task_task_path(task, return_to: "dashboard")
    end
  end

  def detail_data
    recurring? ? { turbo_frame: "task_detail_panel" } : { dashboard_task_detail: "drawer" }
  end

  def detail_onclick
    "event.preventDefault(); window.drawerOpen(this.href)" unless recurring?
  end
end
