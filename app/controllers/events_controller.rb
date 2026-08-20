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
      render partial: "dashboard/feed_rows",
             locals: { events: events, context: :poll, has_more: has_more }

    elsif params[:before_id].present?
      # View more: append next page of older events
      events    = Event.where("id < ?", params[:before_id]).recent.limit(FEED_LIMIT)
      last_date = params[:last_date].present? ? Date.parse(params[:last_date]) : nil
      has_more  = events.size == FEED_LIMIT
      render partial: "dashboard/feed_rows",
             locals: { events: events, context: :append, last_date: last_date, has_more: has_more }

    else
      head :bad_request
    end
  end
end
