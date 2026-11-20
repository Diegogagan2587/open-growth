class Financial::CategoryBudget < ApplicationRecord
  self.table_name = "financial_category_budgets"

  FREQUENCIES = %w[weekly biweekly monthly custom].freeze

  belongs_to :account
  belongs_to :category

  validates :amount, numericality: { greater_than: 0 }
  validates :frequency, inclusion: { in: FREQUENCIES }
  validates :custom_days, numericality: { only_integer: true, greater_than: 0 }, if: -> { frequency == "custom" }
  validates :category_id, uniqueness: { scope: :account_id }
  validate :category_belongs_to_account

  def allowance_between(range_start, range_end)
    cycle_start = starts_on
    total = 0.to_d
    while cycle_start <= range_end
      cycle_end = next_cycle_start(cycle_start) - 1.day
      overlap_start = [ cycle_start, range_start ].max
      overlap_end = [ cycle_end, range_end ].min
      if overlap_start <= overlap_end
        total += amount.to_d * (overlap_end - overlap_start + 1).to_i / (cycle_end - cycle_start + 1).to_d
      end
      cycle_start = cycle_end + 1.day
    end
    total.round(2)
  end

  private

  def next_cycle_start(date)
    case frequency
    when "weekly" then date + 7.days
    when "biweekly" then date + 14.days
    when "monthly"
      month = date.next_month
      Date.new(month.year, month.month, [ starts_on.day, month.end_of_month.day ].min)
    when "custom" then date + custom_days.days
    end
  end

  def category_belongs_to_account
    errors.add(:category, "must belong to the same account") if category && account_id != category.account_id
  end
end
