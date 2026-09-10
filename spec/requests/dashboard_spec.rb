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

      it "groups recent events by date and renders date divider labels" do
        create(:event, occurred_at: Time.current,  event_type: "doorbell_pressed")
        create(:event, occurred_at: 1.day.ago,     event_type: "motion_detected")

        get root_path

        expect(response).to have_http_status(:ok)
        # The _date_divider partial renders the label from event_date_label(date),
        # so "Today" and "Yesterday" must appear when events span two calendar days.
        expect(response.body).to include("Today")
        expect(response.body).to include("Yesterday")
      end

      it "limits recent events to 10" do
        create_list(:event, 12)
        get root_path
        expect(response).to have_http_status(:ok)
        # Each event row renders with a data-event-id attribute; assert exactly 10.
        expect(response.body.scan(/data-event-id=/).length).to eq(10)
      end

      it "does not render a snapshot toggle for events without a snapshot" do
        create(:event)
        get root_path
        expect(response.body).not_to include("Show snapshot")
      end

      it "renders a hidden snapshot toggle for events with a snapshot attached" do
        event = create(:event)
        event.snapshot.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/snapshot.jpg")),
          filename: "snapshot.jpg",
          content_type: "image/jpeg"
        )

        get root_path

        expect(response.body).to include("Show snapshot")
        expect(response.body).to include('data-controller="snapshot"')
        # The <img> tag must not carry a src attribute up front — only a
        # data-src — so the image is never fetched until the user expands it.
        expect(response.body).to match(/<img[^>]*data-snapshot-target="image"[^>]*data-src="[^"]+"/)
      end
    end
  end
end
