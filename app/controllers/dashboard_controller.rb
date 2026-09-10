class DashboardController < ApplicationController
  layout "authenticated"

  def index
    @recent_events_by_date = Event.recent.with_attached_snapshot.limit(10)
                                  .group_by { |e| e.occurred_at.in_time_zone.to_date }
    @newest_snapshot_id = Event.newest_snapshot_attachment_id
  end
end
