class DashboardController < ApplicationController
  layout "authenticated"

  def index
    today = Event.today

    @events_today_count    = today.count
    @doorbell_count        = today.doorbell_pressed.count
    @motion_count          = today.motion_detected.count
    @last_doorbell         = today.doorbell_pressed.recent.first
    @last_motion           = today.motion_detected.recent.first
    @recent_events_by_date = Event.recent.limit(10)
                                  .group_by { |e| e.occurred_at.in_time_zone.to_date }
  end
end
