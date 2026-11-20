class CreateFinancialCategoryBudgets < ActiveRecord::Migration[8.0]
  def change
    create_table :financial_category_budgets do |t|
      t.references :account, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.string :frequency, null: false
      t.integer :custom_days
      t.date :starts_on, null: false
      t.timestamps
    end

    add_index :financial_category_budgets, [ :account_id, :category_id ], unique: true, name: "index_category_budgets_on_account_and_category"
  end
end
