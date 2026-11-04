class Category < ApplicationRecord
  ICONS = %w[💰 🏠 🍽️ 🚗 🛍️ 💊 🎓 🎉 🐾 📱 ✈️ 📦].freeze

  belongs_to :account
  has_many :financial_entries, class_name: "Financial::Entry", dependent: :restrict_with_error
  has_many :expense_templates, dependent: :destroy
  has_many :expenses, dependent: :destroy
  has_many :budget_line_items, dependent: :destroy
  has_many :planned_expenses, dependent: :destroy
  has_many :shopping_items, dependent: :destroy
  has_many :inventory_items, dependent: :destroy

  validates :name, presence: true
  validates :name, uniqueness: { scope: :account_id }
  validates :icon, inclusion: { in: ICONS, allow_blank: true }

  before_validation :set_account, on: :create

  scope :for_account, ->(account) { where(account: account) }

  private

  def set_account
    self.account ||= Current.account if Current.account
  end
end
