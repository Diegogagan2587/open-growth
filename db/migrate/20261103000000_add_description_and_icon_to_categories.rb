class AddDescriptionAndIconToCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :categories, :description, :text
    add_column :categories, :icon, :string
  end
end
