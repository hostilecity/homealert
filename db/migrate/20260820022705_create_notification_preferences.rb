class CreateNotificationPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_preferences do |t|
      t.references :user, null: false, foreign_key: true
      t.boolean :doorbell_pressed, null: false, default: true
      t.boolean :motion_detected,  null: false, default: true

      t.timestamps
    end

    # user_id index already created by t.references above;
    # add a unique constraint on it by removing and re-adding with unique: true
    remove_index :notification_preferences, :user_id
    add_index    :notification_preferences, :user_id, unique: true
  end
end
