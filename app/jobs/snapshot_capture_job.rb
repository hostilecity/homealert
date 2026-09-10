class SnapshotCaptureJob < ApplicationJob
  queue_as :default

  # Captures a still-image snapshot from the camera for the given event (when
  # one is configured) and attaches it to the Event, then dispatches the push
  # notification.
  #
  # The push notification is intentionally sent from *this* job — never
  # directly from the webhook controller — so that a snapshot (when
  # available) is always attached before the alert reaches a user's device.
  # A camera failure (offline, timeout, bad credentials) only means the
  # notification arrives without a photo; it must never suppress the
  # notification itself, so all capture failures are logged and swallowed.
  def perform(event_id)
    event = Event.find_by(id: event_id)

    capture_snapshot(event) if event && ReoLink::Client.configured?

    PushNotificationJob.perform_later(event_id)
  end

  private

  def capture_snapshot(event)
    body, content_type = ReoLink::Client.new.snapshot

    event.snapshot.attach(
      io:           StringIO.new(body),
      filename:     "snapshot-#{event.id}.jpg",
      content_type: content_type
    )

    Rails.logger.info("SnapshotCaptureJob: captured snapshot for event #{event.id}")
  rescue ReoLink::Client::Error => e
    Rails.logger.error("SnapshotCaptureJob: failed to capture snapshot for event #{event.id}: #{e.message}")
  rescue StandardError => e
    Rails.logger.error("SnapshotCaptureJob: unexpected error capturing snapshot for event #{event.id}: #{e.class} #{e.message}")
  end
end
