class AddUserIdToIndex < ActiveRecord::Migration[5.2]
  def change
    remove_index :entry_states, name: 'index_entry_states_unread_on_order_fields'
    add_index :entry_states, [:published, :entry_created_at, :entry_id, :user_id],
              order: {published: :desc, entry_created_at: :desc, entry_id: :desc},
              where: "read = 'false'",
              name: 'index_entry_states_unread_on_order_fields'
  end
end
