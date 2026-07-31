# frozen_string_literal: true

class Reporting::AnswerQuestionJob < ApplicationJob
  queue_as :default

  def perform(turn_id:, account_id:, account_membership_id:)
    turn = Reporting::Turn.joins(:conversation).find_by(
      id: turn_id,
      reporting_conversations: { account_id: account_id, account_membership_id: account_membership_id }
    )
    Reporting::AnswerQuestion.new(turn: turn).call if turn
  end
end
