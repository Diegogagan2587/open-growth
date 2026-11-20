class RenameProjectsTaskComments < ActiveRecord::Migration[8.0]
  def up
    rename_table :projects_task_comments, :task_comments if table_exists?(:projects_task_comments) && !table_exists?(:task_comments)
  end

  def down
    rename_table :task_comments, :projects_task_comments if table_exists?(:task_comments) && !table_exists?(:projects_task_comments)
  end
end
