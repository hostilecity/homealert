require "rails_helper"

RSpec.describe "Webhooks::VpnLogin", type: :request do
  let(:vpn_payload) do
    {
      event:          "vpn_login",
      username:       "rtulino",
      common_name:    "ryans-macbook",
      source_ip:      "203.0.113.42",
      timestamp_unix: 1.minute.ago.to_i.to_s
    }.to_json
  end

  def post_vpn_login(body, content_type: "application/json", host: "localhost")
    post webhooks_vpn_login_path, params: body, headers: { "CONTENT_TYPE" => content_type, "HOST" => host }
  end

  # ------------------------------------------------------------------ #
  # Authentication                                                       #
  # ------------------------------------------------------------------ #
  it "does not require authentication" do
    post_vpn_login(vpn_payload)
    expect(response).not_to redirect_to(login_path)
  end

  it "returns 404 when the hostname is not allowlisted" do
    post_vpn_login(vpn_payload, host: "example.com")
    expect(response).to have_http_status(:not_found)
  end

  it "does not require a CSRF token" do
    # Rails disables forgery protection globally in test. Enable it for this
    # example so that the assertion is a real proof that the controller calls
    # skip_before_action :verify_authenticity_token — without the skip, Rails
    # would raise ActionController::InvalidAuthenticityToken and return 422.
    ActionController::Base.allow_forgery_protection = true
    post_vpn_login(vpn_payload)
    expect(response).not_to have_http_status(:unprocessable_entity)
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  # ------------------------------------------------------------------ #
  # Valid payload                                                         #
  # ------------------------------------------------------------------ #
  describe "POST /webhooks/vpn_login with a valid vpn_login event" do
    it "returns 200 OK" do
      post_vpn_login(vpn_payload)
      expect(response).to have_http_status(:ok)
    end

    it "creates an Event record" do
      expect { post_vpn_login(vpn_payload) }.to change(Event, :count).by(1)
    end

    it "stores the correct event_type" do
      post_vpn_login(vpn_payload)
      expect(Event.last.event_type).to eq("vpn_login")
    end

    it "stores the device_name from username and common_name" do
      post_vpn_login(vpn_payload)
      expect(Event.last.device_name).to eq("rtulino (ryans-macbook)")
    end

    it "stores the source_ip as device_id" do
      post_vpn_login(vpn_payload)
      expect(Event.last.device_id).to eq("203.0.113.42")
    end

    it "enqueues a PushNotificationJob" do
      expect { post_vpn_login(vpn_payload) }
        .to have_enqueued_job(PushNotificationJob)
    end
  end

  # ------------------------------------------------------------------ #
  # Invalid / unknown payloads                                           #
  # ------------------------------------------------------------------ #
  describe "POST /webhooks/vpn_login with an unknown event type" do
    let(:unknown_payload) do
      { event: "vpn_logout", username: "rtulino", source_ip: "10.0.0.1", timestamp_unix: Time.current.to_i.to_s }.to_json
    end

    it "returns 422 Unprocessable Entity" do
      post_vpn_login(unknown_payload)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "does not create an Event" do
      expect { post_vpn_login(unknown_payload) }.not_to change(Event, :count)
    end
  end

  describe "POST /webhooks/vpn_login with a missing event key" do
    let(:missing_event_payload) { { username: "rtulino", source_ip: "10.0.0.1" }.to_json }

    it "returns 422 Unprocessable Entity" do
      post_vpn_login(missing_event_payload)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /webhooks/vpn_login with a non-JSON content type" do
    it "returns 422 Unprocessable Entity" do
      post_vpn_login(vpn_payload, content_type: "text/plain")
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /webhooks/vpn_login with invalid JSON" do
    it "returns 422 Unprocessable Entity" do
      post_vpn_login("this is not json { at all", content_type: "application/json")
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
