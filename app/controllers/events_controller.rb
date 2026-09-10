class EventsController < ApplicationController
  FEED_LIMIT = 10

  def feed
    if params[:poll].present?
      # Polling: re-render the full feed list so the DOM is always consistent.
      # Accepts newest_id so we know whether anything changed since last poll.
      # newest_snapshot_id is a second freshness signal: SnapshotCaptureJob
      # attaches a snapshot asynchronously, sometimes after an event's row has
      # already been polled/rendered without one, so Event.maximum(:id) alone
      # wouldn't notice that update.
      newest_id          = params[:newest_id].to_i
      newest_snapshot_id = params[:newest_snapshot_id].to_i
      max_id             = Event.maximum(:id)
      return head(:no_content) if max_id.nil?

      max_snapshot_id = Event.newest_snapshot_attachment_id
      return head(:no_content) if max_id == newest_id && max_snapshot_id == newest_snapshot_id

      events   = Event.recent.with_attached_snapshot.limit(FEED_LIMIT)
      has_more = events.size == FEED_LIMIT
      render partial: "dashboard/poll_response",
             locals: { events: events, has_more: has_more, newest_snapshot_id: max_snapshot_id }

    elsif params[:before_occurred_at].present?
      # View more: append next page of events older than the given occurred_at.
      # Cursor is occurred_at (not id) to stay consistent with the occurred_at
      # ordering used by Event.recent, avoiding skips/duplicates on clock skew.
      cursor    = Time.zone.parse(params[:before_occurred_at])
      last_date = safe_parse_date(params[:last_date])
      events    = Event.where("occurred_at < ?", cursor).recent.with_attached_snapshot.limit(FEED_LIMIT)
      has_more  = events.size == FEED_LIMIT
      render partial: "dashboard/feed_rows",
             locals: { events: events, context: :append, last_date: last_date, has_more: has_more }

    else
      head :bad_request
    end
  rescue ArgumentError
    head :bad_request
  end

  private

  def safe_parse_date(value)
    Date.parse(value) if value.present?
  rescue ArgumentError
    nil
  end
end
