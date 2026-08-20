class NotificationPreference < ApplicationRecord
  belongs_to :user

  validates :doorbell_pressed, inclusion: { in: [ true, false ] }
  validates :motion_detected,  inclusion: { in: [ true, false ] }

  def self.for_user(user)
    # create_or_find_by! inserts first then falls back to SELECT on unique conflict,
    # making it safe under concurrent access (e.g. simultaneous webhook jobs).
    create_or_find_by!(user: user)
  end

  def enabled_for?(event_type)
    case event_type
    when "doorbell_pressed" then doorbell_pressed?
    when "motion_detected"  then motion_detected?
    else false
    end
  end
end
