class RemoveRedundantEventTypeIndexFromEvents < ActiveRecord::Migration[8.1]
  def change
    remove_index :events, :event_type
  end
end
