# frozen_string_literal: true

class Reports::Ai::TurnsController < ApplicationController
  rate_limit to: 5, within: 1.minute, by: -> { Current.user.id }, with: -> { redirect_back fallback_location: reports_ai_conversations_path, alert: "Please wait before asking another question." }

  def create
    membership = Current.account.account_memberships.find_by!(user: Current.user)
    conversation = membership.reporting_conversations.find(params[:conversation_id])
    Reporting::AnswerQuestion.enqueue!(conversation: conversation, question: params[:question].to_s)
    redirect_to reports_ai_conversation_path(conversation), status: :see_other
  rescue Reporting::AnswerQuestion::AccessDenied, Reporting::AnswerQuestion::QuotaExceeded => error
    redirect_to reports_ai_conversation_path(conversation), alert: error.message
  rescue ActiveRecord::RecordInvalid => error
    redirect_to reports_ai_conversation_path(conversation), alert: error.record.errors.full_messages.to_sentence
  end
end
