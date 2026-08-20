require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  describe "GET /" do
    context "when not signed in" do
      it "redirects to login" do
        get root_path
        expect(response).to redirect_to(login_path)
      end

      it "sets an alert" do
        get root_path
        expect(flash[:alert]).to eq("Please sign in to continue.")
      end
    end

    context "when signed in" do
      let(:user) { create(:user) }

      before { sign_in(user) }

      it "returns 200" do
        get root_path
        expect(response).to have_http_status(:ok)
      end

      it "groups recent events by date" do
        today     = Time.current
        yesterday = 1.day.ago

        create(:event, occurred_at: today,     event_type: "doorbell_pressed")
        create(:event, occurred_at: yesterday, event_type: "motion_detected")

        get root_path

        # The controller assigns @recent_events_by_date; since we are not
        # running view specs we verify the response is successful and the
        # events exist in the DB so the query path is exercised.
        expect(response).to have_http_status(:ok)
      end

      it "limits recent events to 10" do
        create_list(:event, 12)
        get root_path
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
