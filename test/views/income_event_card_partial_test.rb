# frozen_string_literal: true

require "test_helper"

class IncomeEventCardPartialTest < ActionView::TestCase
  test "renders pending income event card with previous balance details" do
    income_event = income_events(:one)
    previous_event = income_events(:two)

    income_event.define_singleton_method(:previous_balance) { -125.50 }
    income_event.define_singleton_method(:previous_income_event) { previous_event }
    income_event.define_singleton_method(:total_planned) { 1250.0 }
    income_event.define_singleton_method(:effective_remaining_budget) { -25.5 }
    income_event.define_singleton_method(:received_date) { nil }
    income_event.define_singleton_method(:received_amount) { nil }
    income_event.define_singleton_method(:is_received?) { false }
    income_event.define_singleton_method(:is_applied?) { false }

    render partial: "income_events/income_event_card", locals: { income_event: income_event }

    assert_selector "h2", text: income_event.description
    assert_text "Expected: #{income_event.expected_date.strftime('%b %d, %Y')}"
    assert_text number_to_currency(income_event.expected_amount)
    assert_text "Previous Balance"
    assert_text previous_event.description
    assert_text number_to_currency(-125.50)
    assert_text number_to_currency(1250.0)
    assert_text number_to_currency(-25.5)
    assert_text "Planning Progress"
    assert_text "25.0%"
    assert_link "Mark Received", href: receive_income_event_path(income_event)
    assert_no_text "Apply All"
    assert_selector "div.border-red-300"
    assert_selector "span.text-red-600", text: number_to_currency(-25.5)
  end

  test "renders received income event card with received section and apply action" do
    income_event = income_events(:one)

    income_event.status = "received"
    income_event.received_date = Date.new(2026, 4, 15)
    income_event.received_amount = 4900.0
    income_event.define_singleton_method(:previous_balance) { 0.0 }
    income_event.define_singleton_method(:previous_income_event) { nil }
    income_event.define_singleton_method(:total_planned) { 2000.0 }
    income_event.define_singleton_method(:effective_remaining_budget) { 2900.0 }
    income_event.define_singleton_method(:is_received?) { true }
    income_event.define_singleton_method(:is_applied?) { false }

    render partial: "income_events/income_event_card", locals: { income_event: income_event }

    assert_text "Received"
    assert_text "#{income_event.received_date.strftime('%b %d')} - #{number_to_currency(income_event.received_amount)}"
    assert_link "Apply All", href: apply_all_income_event_path(income_event)
    assert_no_text "Mark Received"
    assert_selector "span.text-green-600", text: number_to_currency(2900.0)
  end
end
