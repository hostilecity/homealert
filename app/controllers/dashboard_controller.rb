class DashboardController < ApplicationController
  layout "authenticated"

  def index
    @recent_events_by_date = Event.recent.limit(10)
                                  .group_by { |e| e.occurred_at.in_time_zone.to_date }
  end
end
