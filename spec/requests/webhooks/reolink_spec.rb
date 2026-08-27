require "rails_helper"

RSpec.describe "Webhooks::ReoLink", type: :request do
  let(:doorbell_payload) do
    {
      alarm: {
        type:        "visitor",
        deviceModel: "RLC-810A",
        channelName: "Front Door",
        device:      "device-001",
        alarmTime:   1.minute.ago.strftime("%Y-%m-%d %H:%M:%S")
      }
    }.to_json
  end

  let(:motion_payload) do
    {
      alarm: {
        type:        "people",
        deviceModel: "RLC-810A",
        channelName: "Back Yard",
        device:      "device-002",
        alarmTime:   1.minute.ago.strftime("%Y-%m-%d %H:%M:%S")
      }
    }.to_json
  end

  def post_reolink(body, content_type: "application/json", host: "localhost")
    post webhooks_reolink_path, params: body, headers: { "CONTENT_TYPE" => content_type, "HOST" => host }
  end

  # ------------------------------------------------------------------ #
  # Authentication                                                       #
  # ------------------------------------------------------------------ #
  it "does not require authentication" do
    post_reolink(doorbell_payload)
    expect(response).not_to redirect_to(login_path)
  end

  it "returns 404 when the hostname is not allowlisted" do
    post_reolink(doorbell_payload, host: "example.com")
    expect(response).to have_http_status(:not_found)
  end

  it "does not require a CSRF token" do
    # Rails disables forgery protection globally in test. Enable it for this
    # example so that the assertion is a real proof that the controller calls
    # skip_before_action :verify_authenticity_token — without the skip, Rails
    # would raise ActionController::InvalidAuthenticityToken and return 422.
    ActionController::Base.allow_forgery_protection = true
    post_reolink(doorbell_payload)
    expect(response).not_to have_http_status(:unprocessable_entity)
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  # ------------------------------------------------------------------ #
  # Valid payloads                                                        #
  # ------------------------------------------------------------------ #
  describe "POST /webhooks/reolink with a doorbell_pressed event" do
    it "returns 200 OK" do
      post_reolink(doorbell_payload)
      expect(response).to have_http_status(:ok)
    end

    it "creates an Event record" do
      expect { post_reolink(doorbell_payload) }.to change(Event, :count).by(1)
    end

    it "stores the correct event_type" do
      post_reolink(doorbell_payload)
      expect(Event.last.event_type).to eq("doorbell_pressed")
    end

    it "enqueues a PushNotificationJob" do
      expect { post_reolink(doorbell_payload) }
        .to have_enqueued_job(PushNotificationJob)
    end
  end

  describe "POST /webhooks/reolink with a motion_detected event" do
    it "returns 200 OK" do
      post_reolink(motion_payload)
      expect(response).to have_http_status(:ok)
    end

    it "creates an Event record" do
      expect { post_reolink(motion_payload) }.to change(Event, :count).by(1)
    end

    it "stores the correct event_type" do
      post_reolink(motion_payload)
      expect(Event.last.event_type).to eq("motion_detected")
    end

    it "enqueues a PushNotificationJob" do
      expect { post_reolink(motion_payload) }
        .to have_enqueued_job(PushNotificationJob)
    end
  end

  # ------------------------------------------------------------------ #
  # Invalid / unknown payloads                                           #
  # ------------------------------------------------------------------ #
  describe "POST /webhooks/reolink with an unknown event type" do
    let(:unknown_payload) do
      { alarm: { type: "unknown_type", device: "dev-1", alarmTime: Time.current.to_s } }.to_json
    end

    it "returns 422 Unprocessable Entity" do
      post_reolink(unknown_payload)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "does not create an Event" do
      expect { post_reolink(unknown_payload) }.not_to change(Event, :count)
    end
  end

  describe "POST /webhooks/reolink with a missing alarm key" do
    let(:missing_alarm_payload) { { data: "something" }.to_json }

    it "returns 422 Unprocessable Entity" do
      post_reolink(missing_alarm_payload)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /webhooks/reolink with a non-JSON content type" do
    it "returns 422 Unprocessable Entity" do
      post_reolink(doorbell_payload, content_type: "text/plain")
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /webhooks/reolink with invalid JSON" do
    it "returns 422 Unprocessable Entity" do
      post_reolink("this is not json { at all", content_type: "application/json")
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
