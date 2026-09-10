class SnapshotRetentionJob < ApplicationJob
  queue_as :default

  # Days to keep captured snapshots before purging them. Set
  # SNAPSHOT_RETENTION_DAYS=0 to keep snapshots indefinitely.
  DEFAULT_RETENTION_DAYS = 30

  def perform
    days = retention_days
    return if days.zero?

    cutoff = days.days.ago
    purged = 0

    Event.joins(:snapshot_attachment)
         .where(active_storage_attachments: { created_at: ...cutoff })
         .find_each do |event|
      event.snapshot.purge
      purged += 1
    end

    Rails.logger.info("SnapshotRetentionJob: purged #{purged} snapshot(s) older than #{days} day(s)") if purged.positive?
  end

  private

  def retention_days
    Integer(ENV["SNAPSHOT_RETENTION_DAYS"].presence || DEFAULT_RETENTION_DAYS)
  rescue ArgumentError, TypeError
    DEFAULT_RETENTION_DAYS
  end
end
