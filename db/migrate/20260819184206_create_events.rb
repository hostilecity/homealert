class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.string   :event_type,  null: false
      t.string   :device_name, null: false
      t.string   :device_id,   null: false
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :events, :event_type
    add_index :events, :occurred_at
    add_index :events, [ :event_type, :occurred_at ]
  end
end
