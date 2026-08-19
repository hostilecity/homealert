class Event < ApplicationRecord
  TYPES = %w[doorbell_pressed motion_detected].freeze

  validates :event_type,  presence: true, inclusion: { in: TYPES }
  validates :device_name, presence: true
  validates :device_id,   presence: true
  validates :occurred_at, presence: true

  scope :recent,           -> { order(occurred_at: :desc) }
  scope :today,            -> { where(occurred_at: Time.current.beginning_of_day..) }
  scope :doorbell_pressed, -> { where(event_type: "doorbell_pressed") }
  scope :motion_detected,  -> { where(event_type: "motion_detected") }
end
