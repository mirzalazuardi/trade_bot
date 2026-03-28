class AddRememberMeToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :sessions, :remember_me, :boolean, default: false, null: false
  end
end
