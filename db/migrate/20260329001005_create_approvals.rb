class CreateApprovals < ActiveRecord::Migration[8.1]
  def change
    create_table :approvals do |t|
      t.references :user, null: false, foreign_key: true
      t.bigint :bot_id, null: false
      t.enum :status, enum_type: :approval_status, default: "pending"
      t.string :side
      t.decimal :quantity, precision: 20, scale: 8
      t.decimal :price, precision: 20, scale: 8
      t.decimal :ml_confidence, precision: 5, scale: 2
      t.decimal :estimated_fee, precision: 20, scale: 8
      t.datetime :expires_at

      t.timestamps
    end

    add_foreign_key :approvals, :bots, column: :bot_id
    add_index :approvals, [ :bot_id, :status ]
    add_index :approvals, :expires_at
  end
end
