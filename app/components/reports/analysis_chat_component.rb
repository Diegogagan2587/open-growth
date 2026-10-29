# frozen_string_literal: true

class Reports::AnalysisChatComponent < ViewComponent::Base
  def initialize(conversation:, membership:)
    @conversation = conversation
    @membership = membership
  end

  def can_ask?
    @membership.ai_reports_available? && @membership.ai_reports_requests_remaining.positive?
  end

  def remaining
    @membership.ai_reports_requests_remaining
  end

  def career?
    @conversation.career?
  end

  def domain_label
    career? ? "Career analysis" : "Financial analysis"
  end
end
