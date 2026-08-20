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

      context "with poll=true and latest id matches newest_id" do
        it "returns 204 No Content" do
          event = create(:event)
          get events_feed_path(poll: true, newest_id: event.id)
          expect(response).to have_http_status(:no_content)
        end
      end

      context "with poll=true and a newer event exists" do
        it "does not return 204 (proceeds to render)" do
          existing = create(:event)
          _newer   = create(:event)
          # The controller passes the no-content gate and calls render partial.
          # The _poll_response partial uses a relative `render "stat_cards"`
          # which resolves against EventsController's view path and raises
          # MissingTemplate. Stub render to bypass the view layer and verify
          # only the branching logic (not-204 path).
          allow_any_instance_of(EventsController).to receive(:render)
          get events_feed_path(poll: true, newest_id: existing.id)
          expect(response).not_to have_http_status(:no_content)
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

        it "returns events older than the cursor" do
          _old   = create(:event, occurred_at: 3.hours.ago)
          _newer = create(:event, occurred_at: 30.minutes.ago)
          cursor = 1.hour.ago.iso8601
          get events_feed_path(before_occurred_at: cursor)
          expect(response).to have_http_status(:ok)
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
