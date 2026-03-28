class AddPairToApprovals < ActiveRecord::Migration[8.1]
  def change
    add_column :approvals, :pair, :string
  end
end
