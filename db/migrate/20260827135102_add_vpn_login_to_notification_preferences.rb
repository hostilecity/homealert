class AddVpnLoginToNotificationPreferences < ActiveRecord::Migration[8.1]
  def change
    add_column :notification_preferences, :vpn_login, :boolean, null: false, default: false
  end
end
