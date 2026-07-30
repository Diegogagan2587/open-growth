# frozen_string_literal: true

class Reporting::ExpireStaleTurnsJob < ApplicationJob
  queue_as :default

  def perform
    Reporting::Turn.stale(before: 15.minutes.ago).find_each do |turn|
      turn.with_lock do
        next unless turn.status.in?(%w[queued processing])

        called_provider = turn.status == "processing"
        turn.usage_event&.update!(
          status: called_provider ? "provider_failed" : "canceled",
          error_code: "stale_request"
        )
        turn.update!(
          status: called_provider ? "failed" : "canceled",
          error_code: "stale_request",
          error_message: "The analysis timed out. Please ask again."
        )
      end
    end
  end
end
