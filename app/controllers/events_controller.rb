class EventsController < ApplicationController
  FEED_LIMIT = 10

  def feed
    if params[:after_id].present?
      # Polling: events newer than after_id, oldest-first so we can prepend in order
      events = Event.where("id > ?", params[:after_id]).recent.limit(FEED_LIMIT)
      render partial: "dashboard/feed_rows",
             locals: { events: events, context: :prepend, last_date: nil }
    elsif params[:before_id].present?
      # View more: events older than before_id, newest-first
      events = Event.where("id < ?", params[:before_id]).recent.limit(FEED_LIMIT)
      last_date = params[:last_date].present? ? Date.parse(params[:last_date]) : nil
      has_more  = events.size == FEED_LIMIT
      render partial: "dashboard/feed_rows",
             locals: { events: events, context: :append, last_date: last_date, has_more: has_more }
    else
      head :bad_request
    end
  end
end
