class LinkShoppingItemsToFinancialEntries < ActiveRecord::Migration[8.0]
  def change
    add_reference :shopping_items, :financial_entry, foreign_key: true
  end
end
