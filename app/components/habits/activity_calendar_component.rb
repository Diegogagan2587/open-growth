# frozen_string_literal: true

class Habits::ActivityCalendarComponent < ViewComponent::Base
  def initialize(calendar:)
    @calendar = calendar
  end

  attr_reader :calendar
end
