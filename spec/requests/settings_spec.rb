require "rails_helper"

RSpec.describe "Settings", type: :request do
  let(:user) { create(:user) }

  # ------------------------------------------------------------------ #
  # GET /settings                                                        #
  # ------------------------------------------------------------------ #
  describe "GET /settings" do
    context "when not signed in" do
      it "redirects to login" do
        get settings_path
        expect(response).to redirect_to(login_path)
      end
    end

    context "when signed in" do
      before { sign_in(user) }

      it "returns 200" do
        get settings_path
        expect(response).to have_http_status(:ok)
      end

      it "creates or finds a notification preference for the user" do
        expect {
          get settings_path
        }.to change(NotificationPreference, :count).by(1)
      end

      it "does not duplicate the notification preference on subsequent requests" do
        create(:notification_preference, user: user)
        expect {
          get settings_path
        }.not_to change(NotificationPreference, :count)
        expect(response).to have_http_status(:ok)
      end

      it "lists every push subscription belonging to the user" do
        older  = create(:push_subscription, user: user, created_at: 2.days.ago, device_label: "Chrome on macOS")
        recent = create(:push_subscription, user: user, created_at: 1.hour.ago, device_label: "Safari on iPhone")

        get settings_path

        expect(response.body).to include("data-device-id=\"#{older.id}\"")
        expect(response.body).to include("data-device-id=\"#{recent.id}\"")
        expect(response.body).to include("Chrome on macOS")
        expect(response.body).to include("Safari on iPhone")
      end

      it "renders the endpoint digest rather than the raw endpoint" do
        subscription = create(:push_subscription, user: user)

        get settings_path

        expect(response.body).to include(subscription.endpoint_digest)
        expect(response.body).not_to include(subscription.endpoint)
      end

      it "does not list another user's subscriptions" do
        other = create(:push_subscription, user: create(:user), device_label: "Someone Else")

        get settings_path

        expect(response.body).not_to include("data-device-id=\"#{other.id}\"")
      end

      it "renders the enable-notifications control even when a device is already registered" do
        create(:push_subscription, user: user)

        get settings_path

        expect(response.body).to include("data-push-target=\"subscribeBtn\"")
      end
    end
  end

  # ------------------------------------------------------------------ #
  # PATCH /settings/notification_preferences                             #
  # ------------------------------------------------------------------ #
  describe "PATCH /settings/notification_preferences" do
    context "when not signed in" do
      it "redirects to login" do
        patch settings_notification_preferences_path,
              params: { preference: { doorbell_pressed: true, motion_detected: false } }
        expect(response).to redirect_to(login_path)
      end
    end

    context "when signed in" do
      before { sign_in(user) }

      context "with valid params" do
        it "returns 200 OK" do
          patch settings_notification_preferences_path,
                params: { preference: { doorbell_pressed: true, motion_detected: false } }
          expect(response).to have_http_status(:ok)
        end

        it "updates doorbell_pressed preference" do
          pref = create(:notification_preference, user: user, doorbell_pressed: true)
          patch settings_notification_preferences_path,
                params: { preference: { doorbell_pressed: false, motion_detected: true } }
          expect(pref.reload.doorbell_pressed).to be(false)
        end

        it "updates motion_detected preference" do
          pref = create(:notification_preference, user: user, motion_detected: true)
          patch settings_notification_preferences_path,
                params: { preference: { doorbell_pressed: true, motion_detected: false } }
          expect(pref.reload.motion_detected).to be(false)
        end
      end

      context "with missing preference param" do
        it "returns 422 Unprocessable Entity" do
          patch settings_notification_preferences_path, params: {}
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "returns a JSON error body" do
          patch settings_notification_preferences_path, params: {}
          json = JSON.parse(response.body)
          expect(json).to have_key("error")
        end
      end
    end
  end
end
