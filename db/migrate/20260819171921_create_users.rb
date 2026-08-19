class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :google_uid
      t.string :name
      t.string :email
      t.string :avatar_url

      t.timestamps
    end
    add_index :users, :google_uid, unique: true
    add_index :users, :email, unique: true
  end
end
