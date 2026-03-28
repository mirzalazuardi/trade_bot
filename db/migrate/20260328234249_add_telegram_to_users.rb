class AddTelegramToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :telegram_chat_id, :string
    add_column :users, :telegram_user_id, :string
    add_column :users, :telegram_enabled, :boolean, default: false
  end
end
