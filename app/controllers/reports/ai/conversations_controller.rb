# frozen_string_literal: true

class Reports::Ai::ConversationsController < ApplicationController
  before_action :set_membership
  before_action :set_conversation, only: %i[show destroy]

  def index
    @conversations = @membership.reporting_conversations.recent_first
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
    params.expect(reporting_conversation: [ :title ])
  end

end
