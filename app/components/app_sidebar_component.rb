# frozen_string_literal: true

class AppSidebarComponent < ViewComponent::Base
  def initialize(current_controller: "")
    @current_controller = current_controller.to_s
  end

  attr_reader :current_controller

  def active_controller?(*names)
    names.flatten.map(&:to_s).include?(current_controller)
  end

  def dashboard_active?
    current_controller.blank? || active_controller?("dashboard", "home")
  end

  def finance_active?
    current_controller.start_with?("finance", "financial/") && !current_controller.start_with?("financial/reports/")
  end

  def settings_active?
    active_controller?("settings", "categories")
  end

  def career_active?
    current_controller.start_with?("career/")
  end

  def nav_label_classes
    "truncate"
  end
end
