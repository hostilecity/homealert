require "rails_helper"

RSpec.describe PushNotificationJob, type: :job do
  include ActiveJob::TestHelper

  let(:user)         { create(:user) }
  let(:event)        { create(:event, event_type: "doorbell_pressed") }
  let(:subscription) { create(:push_subscription, user: user) }

  let(:vapid_public_key)  { "BEl62iUYgUivxIkv69yViEuiBIa-Ib9-SkvMeAtA3LFgDzkrxZJjSgSnfckjBJuBkr3qBUYIHBQFLXYp5Nksh8U" }
  let(:vapid_private_key) { "uDNx84zULEqph71mqea6GneldZCVVhOEct3FxMnXPSg" }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    stub_const("ENV", ENV.to_hash.merge(
      "VAPID_PUBLIC_KEY"  => vapid_public_key,
      "VAPID_PRIVATE_KEY" => vapid_private_key
    ))
    allow(WebPush).to receive(:payload_send).and_return(nil)
    subscription # ensure the subscription record is persisted
  end

  # ------------------------------------------------------------------ #
  # Early-exit: event not found                                          #
  # ------------------------------------------------------------------ #
  describe "when the event does not exist" do
    it "returns early without sending any push notifications" do
      described_class.perform_now(999_999)
      expect(WebPush).not_to have_received(:payload_send)
    end
  end

  # ------------------------------------------------------------------ #
  # Early-exit: VAPID keys not configured                                #
  # ------------------------------------------------------------------ #
  describe "when VAPID keys are not set" do
    before do
      stub_const("ENV", ENV.to_hash.merge(
        "VAPID_PUBLIC_KEY"  => nil,
        "VAPID_PRIVATE_KEY" => nil
      ))
    end

    it "returns early without sending any push notifications" do
      described_class.perform_now(event.id)
      expect(WebPush).not_to have_received(:payload_send)
    end

    it "logs an error" do
      expect(Rails.logger).to receive(:error).with(/VAPID_PUBLIC_KEY or VAPID_PRIVATE_KEY not set/)
      described_class.perform_now(event.id)
    end
  end

  describe "when VAPID public key is blank" do
    before do
      stub_const("ENV", ENV.to_hash.merge(
        "VAPID_PUBLIC_KEY"  => "",
        "VAPID_PRIVATE_KEY" => vapid_private_key
      ))
    end

    it "returns early" do
      described_class.perform_now(event.id)
      expect(WebPush).not_to have_received(:payload_send)
    end
  end

  # ------------------------------------------------------------------ #
  # Sending notifications                                                #
  # ------------------------------------------------------------------ #
  describe "when everything is configured correctly" do
    before { create(:notification_preference, user: user, doorbell_pressed: true, motion_detected: true) }

    it "sends a push notification to each subscriber" do
      described_class.perform_now(event.id)
      expect(WebPush).to have_received(:payload_send).once
    end

    it "passes the correct endpoint to WebPush" do
      described_class.perform_now(event.id)
      expect(WebPush).to have_received(:payload_send)
        .with(hash_including(endpoint: subscription.endpoint))
    end

    it "passes the correct p256dh key" do
      described_class.perform_now(event.id)
      expect(WebPush).to have_received(:payload_send)
        .with(hash_including(p256dh: subscription.p256dh_key))
    end

    it "passes the correct auth key" do
      described_class.perform_now(event.id)
      expect(WebPush).to have_received(:payload_send)
        .with(hash_including(auth: subscription.auth_key))
    end

    it "includes a JSON payload with the notification title" do
      described_class.perform_now(event.id)
      expect(WebPush).to have_received(:payload_send) do |args|
        parsed = JSON.parse(args[:message])
        expect(parsed["title"]).to eq("Doorbell pressed")
      end
    end

    it "includes the device name in the payload body" do
      described_class.perform_now(event.id)
      expect(WebPush).to have_received(:payload_send) do |args|
        parsed = JSON.parse(args[:message])
        expect(parsed["body"]).to eq(event.device_name)
      end
    end
  end

  # ------------------------------------------------------------------ #
  # Preference filtering                                                 #
  # ------------------------------------------------------------------ #
  describe "when the subscriber has doorbell notifications disabled" do
    before { create(:notification_preference, user: user, doorbell_pressed: false, motion_detected: true) }

    it "skips that subscriber for a doorbell_pressed event" do
      described_class.perform_now(event.id)
      expect(WebPush).not_to have_received(:payload_send)
    end
  end

  describe "when the subscriber has motion notifications disabled" do
    let(:event) { create(:event, event_type: "motion_detected") }

    before { create(:notification_preference, user: user, doorbell_pressed: true, motion_detected: false) }

    it "skips that subscriber for a motion_detected event" do
      described_class.perform_now(event.id)
      expect(WebPush).not_to have_received(:payload_send)
    end
  end

  describe "with multiple subscribers" do
    let(:user2)  { create(:user) }
    let!(:sub2)  { create(:push_subscription, user: user2) }

    before do
      create(:notification_preference, user: user,  doorbell_pressed: true,  motion_detected: true)
      create(:notification_preference, user: user2, doorbell_pressed: false, motion_detected: true)
    end

    it "sends only to subscribers with the preference enabled" do
      described_class.perform_now(event.id)
      # user has doorbell enabled; user2 does not
      expect(WebPush).to have_received(:payload_send).once
    end
  end

  # ------------------------------------------------------------------ #
  # Error handling                                                       #
  # ------------------------------------------------------------------ #
  shared_context "with preference enabled" do
    before { create(:notification_preference, user: user, doorbell_pressed: true, motion_detected: true) }
  end

  describe "when WebPush raises ExpiredSubscription" do
    include_context "with preference enabled"

    # WebPush::ExpiredSubscription inherits from WebPush::ResponseError and requires
    # two constructor arguments (response, host). Build a proper instance to raise.
    let(:stale_response) { double("response", code: "410", body: "expired") }
    let(:expired_error)  { WebPush::ExpiredSubscription.new(stale_response, "https://push.example.com") }

    before do
      allow(WebPush).to receive(:payload_send).and_raise(expired_error)
    end

    it "destroys the subscription" do
      expect { described_class.perform_now(event.id) }
        .to change(PushSubscription, :count).by(-1)
    end

    it "does not re-raise the error" do
      expect { described_class.perform_now(event.id) }.not_to raise_error
    end
  end

  describe "when WebPush raises InvalidSubscription" do
    include_context "with preference enabled"

    let(:invalid_response) { double("response", code: "404", body: "not found") }
    let(:invalid_error)    { WebPush::InvalidSubscription.new(invalid_response, "https://push.example.com") }

    before do
      allow(WebPush).to receive(:payload_send).and_raise(invalid_error)
    end

    it "destroys the subscription" do
      expect { described_class.perform_now(event.id) }
        .to change(PushSubscription, :count).by(-1)
    end

    it "does not re-raise the error" do
      expect { described_class.perform_now(event.id) }.not_to raise_error
    end
  end

  describe "when WebPush raises ResponseError" do
    include_context "with preference enabled"

    # WebPush::ResponseError#initialize calls response.body, so the double must respond to it
    let(:fake_response) { double("response", code: "410", body: "Gone") }
    let(:error)         { WebPush::ResponseError.new(fake_response, "https://example.com") }

    before do
      subscription
      allow(WebPush).to receive(:payload_send).and_raise(error)
    end

    it "logs an error" do
      expect(Rails.logger).to receive(:error).with(/WebPush response error/)
      described_class.perform_now(event.id)
    end

    it "does not re-raise the error" do
      expect { described_class.perform_now(event.id) }.not_to raise_error
    end

    it "does not destroy the subscription" do
      expect { described_class.perform_now(event.id) }
        .not_to change(PushSubscription, :count)
    end
  end

  describe "when WebPush raises WebPush::Error" do
    include_context "with preference enabled"

    before do
      subscription
      allow(WebPush).to receive(:payload_send).and_raise(WebPush::Error, "generic error")
    end

    it "logs an error" do
      expect(Rails.logger).to receive(:error).with(/WebPush error/)
      described_class.perform_now(event.id)
    end

    it "does not re-raise the error" do
      expect { described_class.perform_now(event.id) }.not_to raise_error
    end
  end

  describe "when WebPush raises ArgumentError" do
    include_context "with preference enabled"

    before do
      subscription
      allow(WebPush).to receive(:payload_send).and_raise(ArgumentError, "bad keys")
    end

    it "logs an error" do
      expect(Rails.logger).to receive(:error).with(/invalid VAPID or subscription keys/i)
      described_class.perform_now(event.id)
    end

    it "does not re-raise the error" do
      expect { described_class.perform_now(event.id) }.not_to raise_error
    end
  end

  # ------------------------------------------------------------------ #
  # notification_title helper                                            #
  # ------------------------------------------------------------------ #
  describe "notification title" do
    before { create(:notification_preference, user: user, doorbell_pressed: true, motion_detected: true) }

    it 'uses "Doorbell pressed" for doorbell_pressed events' do
      described_class.perform_now(event.id)
      expect(WebPush).to have_received(:payload_send) do |args|
        expect(JSON.parse(args[:message])["title"]).to eq("Doorbell pressed")
      end
    end

    it 'uses "Motion detected" for motion_detected events' do
      motion_event = create(:event, event_type: "motion_detected")
      described_class.perform_now(motion_event.id)
      expect(WebPush).to have_received(:payload_send) do |args|
        expect(JSON.parse(args[:message])["title"]).to eq("Motion detected")
      end
    end
  end
end
