class Event < ApplicationRecord
  TYPES = %w[doorbell_pressed motion_detected vpn_login].freeze

  has_one_attached :snapshot

  validates :event_type,  presence: true, inclusion: { in: TYPES }
  validates :device_name, presence: true
  validates :device_id,   presence: true
  validates :occurred_at, presence: true

  scope :recent,           -> { order(occurred_at: :desc) }
  scope :today,            -> { where(occurred_at: Time.current.beginning_of_day..) }
  scope :doorbell_pressed, -> { where(event_type: "doorbell_pressed") }
  scope :motion_detected,  -> { where(event_type: "motion_detected") }
  scope :vpn_login,        -> { where(event_type: "vpn_login") }

  # Used by the dashboard poll endpoint as an extra freshness signal: a
  # snapshot can finish attaching (asynchronously, after SnapshotCaptureJob
  # runs) after an event's row has already been rendered, with no new Event
  # row to trigger a normal poll refresh. Watching this value alongside
  # Event.maximum(:id) ensures the poll still notices and re-renders once the
  # snapshot shows up.
  def self.newest_snapshot_attachment_id
    ActiveStorage::Attachment.where(record_type: name, name: "snapshot").maximum(:id) || 0
  end
end
