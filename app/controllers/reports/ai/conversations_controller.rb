# frozen_string_literal: true

class Reports::Ai::ConversationsController < ApplicationController
  before_action :set_membership
  before_action :set_conversation, only: %i[show destroy]

  def index
    @conversations = @membership.reporting_conversations.recent_first
    @date_from = parsed_date(params[:from]) || Date.current.beginning_of_year
    @date_to = parsed_date(params[:to]) || Date.current
  end

  def create
    unless @membership.ai_reports_available?
      redirect_to reports_ai_conversations_path, alert: "AI analysis is not enabled for this membership."
      return
    end

    @conversation = @membership.reporting_conversations.build(conversation_params.merge(account: Current.account))
    if @conversation.save
      redirect_to reports_ai_conversation_path(@conversation), notice: "Analysis conversation created."
    else
      @conversations = @membership.reporting_conversations.recent_first
      @date_from = @conversation.date_from
      @date_to = @conversation.date_to
      render :index, status: :unprocessable_entity
    end
  end

  def show
  end

  def destroy
    @conversation.destroy!
    redirect_to reports_ai_conversations_path, status: :see_other, notice: "Conversation deleted. Usage history was retained."
  end

  private

  def set_membership
    @membership = Current.account.account_memberships.find_by!(user: Current.user)
  end

  def set_conversation
    @conversation = @membership.reporting_conversations.find(params[:id])
  end

  def conversation_params
    params.expect(reporting_conversation: [ :title, :date_from, :date_to ])
  end

  def parsed_date(value)
    Date.iso8601(value) if value.present?
  rescue Date::Error
    nil
  end
end
