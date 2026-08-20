class EventsController < ApplicationController
  FEED_LIMIT = 10

  def feed
    if params[:poll].present?
      # Polling: re-render the full feed list so the DOM is always consistent.
      # Accepts newest_id so we know whether anything changed since last poll.
      newest_id = params[:newest_id].to_i
      latest    = Event.recent.first
      return head(:no_content) if latest.nil? || latest.id == newest_id

      events   = Event.recent.limit(FEED_LIMIT)
      has_more = events.size == FEED_LIMIT
      render partial: "dashboard/poll_response",
             locals: { events: events, has_more: has_more }

    elsif params[:before_occurred_at].present?
      # View more: append next page of events older than the given occurred_at.
      # Cursor is occurred_at (not id) to stay consistent with the occurred_at
      # ordering used by Event.recent, avoiding skips/duplicates on clock skew.
      cursor    = Time.zone.parse(params[:before_occurred_at])
      last_date = safe_parse_date(params[:last_date])
      events    = Event.where("occurred_at < ?", cursor).recent.limit(FEED_LIMIT)
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
