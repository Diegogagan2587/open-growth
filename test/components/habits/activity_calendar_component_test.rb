# frozen_string_literal: true

require "test_helper"

class Habits::ActivityCalendarComponentTest < ViewComponent::TestCase
  def test_component_renders_52_weeks_and_a_zero_activity_day
    user = users(:one)
    calendar = Habit::ActivityCalendar.new(account: user.accounts.first, user: user, today: Date.current)
    html = render_inline(Habits::ActivityCalendarComponent.new(calendar: calendar))
    assert_equal 52, html.css("[role='img'] > div").size
    assert_equal 0, html.at_css("[data-date='#{Date.current}']")["data-count"].to_i
  end
end
