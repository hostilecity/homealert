require "rails_helper"

RSpec.describe "Events", type: :request do
  let(:user) { create(:user) }

  describe "GET /events/feed" do
    context "when not signed in" do
      it "redirects to login" do
        get events_feed_path(poll: true)
        expect(response).to redirect_to(login_path)
      end
    end

    context "when signed in" do
      before { sign_in(user) }

      # ------------------------------------------------------------------ #
      # poll mode                                                            #
      # ------------------------------------------------------------------ #
      context "with poll=true and no events in the database" do
        it "returns 204 No Content" do
          get events_feed_path(poll: true, newest_id: 0)
          expect(response).to have_http_status(:no_content)
        end
      end

      context "with poll=true and newest_id matches the maximum event id" do
        it "returns 204 No Content" do
          event = create(:event)
          get events_feed_path(poll: true, newest_id: event.id)
          expect(response).to have_http_status(:no_content)
        end
      end

      context "with poll=true and a newer event exists (higher id, later occurred_at)" do
        it "returns 200 and renders the poll response partial" do
          existing = create(:event)
          _newer   = create(:event)
          get events_feed_path(poll: true, newest_id: existing.id)
          expect(response).to have_http_status(:ok)
          # The _poll_response partial wraps stat cards and feed rows in
          # named divs that the Stimulus feed controller targets.
          expect(response.body).to include("poll-stat-cards")
          expect(response.body).to include("poll-feed-rows")
        end
      end

      context "with poll=true and a new event exists with an earlier occurred_at than the current newest" do
        it "returns 200 so the new event is not missed" do
          # Simulate a doorbell event already visible in the feed (high occurred_at).
          doorbell = create(:event, :doorbell_pressed, occurred_at: 1.hour.ago)
          # A VPN login arrives with timestamp slightly behind the doorbell — its
          # occurred_at sorts below the doorbell but its id is higher.
          _vpn = create(:event, :vpn_login, occurred_at: 2.hours.ago)

          # Client reports it has seen up to the doorbell's id; the VPN event
          # has a higher id and must not be suppressed.
          get events_feed_path(poll: true, newest_id: doorbell.id)
          expect(response).to have_http_status(:ok)
        end
      end

      # ------------------------------------------------------------------ #
      # cursor / pagination mode                                             #
      # ------------------------------------------------------------------ #
      context "with before_occurred_at param" do
        it "returns 200" do
          create(:event, occurred_at: 2.hours.ago)
          cursor = 1.hour.ago.iso8601
          get events_feed_path(before_occurred_at: cursor)
          expect(response).to have_http_status(:ok)
        end

        it "returns only events older than the cursor" do
          old_event  = create(:event, occurred_at: 3.hours.ago, device_name: "OldCamera")
          new_event  = create(:event, occurred_at: 30.minutes.ago, device_name: "NewCamera")
          cursor     = 1.hour.ago.iso8601
          get events_feed_path(before_occurred_at: cursor)
          expect(response).to have_http_status(:ok)
          expect(response.body).to include(old_event.device_name)
          expect(response.body).not_to include(new_event.device_name)
        end

        it "accepts an optional last_date param" do
          create(:event, occurred_at: 2.hours.ago)
          cursor    = 1.hour.ago.iso8601
          last_date = Date.yesterday.to_s
          get events_feed_path(before_occurred_at: cursor, last_date: last_date)
          expect(response).to have_http_status(:ok)
        end
      end

      context "with an out-of-range before_occurred_at param (raises ArgumentError)" do
        it "returns 400 Bad Request" do
          # Time.zone.parse raises ArgumentError for out-of-range values such
          # as month 13; plain nonsense strings return nil and reach the query.
          get events_feed_path(before_occurred_at: "2024-13-45")
          expect(response).to have_http_status(:bad_request)
        end
      end

      # ------------------------------------------------------------------ #
      # missing params                                                       #
      # ------------------------------------------------------------------ #
      context "with no recognised params" do
        it "returns 400 Bad Request" do
          get events_feed_path
          expect(response).to have_http_status(:bad_request)
        end
      end
    end
  end
end
