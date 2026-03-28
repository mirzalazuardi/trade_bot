class AddUserIdToMlModels < ActiveRecord::Migration[8.1]
  def change
    add_reference :ml_models, :user, null: false, foreign_key: true
  end
end
