require "rails_helper"

RSpec.describe SnapshotCaptureJob, type: :job do
  include ActiveJob::TestHelper

  let(:event) { create(:event, event_type: "doorbell_pressed") }
  let(:image_body) { File.binread(Rails.root.join("spec/fixtures/files/snapshot.jpg")) }

  describe "when the event does not exist" do
    it "still enqueues a PushNotificationJob" do
      expect { described_class.perform_now(999_999) }
        .to have_enqueued_job(PushNotificationJob).with(999_999)
    end

    it "does not attempt a snapshot capture" do
      expect(ReoLink::Client).not_to receive(:new)
      described_class.perform_now(999_999)
    end
  end

  describe "when ReoLink is not configured (REOLINK_HOST blank)" do
    before { stub_const("ENV", ENV.to_hash.merge("REOLINK_HOST" => nil)) }

    it "does not attempt a snapshot capture" do
      expect(ReoLink::Client).not_to receive(:new)
      described_class.perform_now(event.id)
    end

    it "still enqueues the PushNotificationJob" do
      expect { described_class.perform_now(event.id) }
        .to have_enqueued_job(PushNotificationJob).with(event.id)
    end

    it "leaves the event without a snapshot" do
      described_class.perform_now(event.id)
      expect(event.reload.snapshot).not_to be_attached
    end
  end

  describe "when ReoLink is configured and the capture succeeds" do
    before do
      stub_const("ENV", ENV.to_hash.merge(
        "REOLINK_HOST"     => "10.27.140.51",
        "REOLINK_USERNAME" => "admin",
        "REOLINK_PASSWORD" => "this4you"
      ))
      allow_any_instance_of(ReoLink::Client).to receive(:snapshot).and_return([ image_body, "image/jpeg" ])
    end

    it "attaches the snapshot to the event" do
      described_class.perform_now(event.id)

      expect(event.reload.snapshot).to be_attached
      expect(event.snapshot.content_type).to eq("image/jpeg")
    end

    it "enqueues the PushNotificationJob after attaching" do
      expect { described_class.perform_now(event.id) }
        .to have_enqueued_job(PushNotificationJob).with(event.id)
    end
  end

  describe "when ReoLink is configured but the capture fails" do
    before do
      stub_const("ENV", ENV.to_hash.merge(
        "REOLINK_HOST"     => "10.27.140.51",
        "REOLINK_USERNAME" => "admin",
        "REOLINK_PASSWORD" => "this4you"
      ))
      allow_any_instance_of(ReoLink::Client).to receive(:snapshot)
        .and_raise(ReoLink::Client::Error, "Timed out contacting camera")
    end

    it "does not attach a snapshot" do
      described_class.perform_now(event.id)
      expect(event.reload.snapshot).not_to be_attached
    end

    it "logs the failure" do
      expect(Rails.logger).to receive(:error).with(/failed to capture snapshot/)
      described_class.perform_now(event.id)
    end

    it "still enqueues the PushNotificationJob so the alert is not lost" do
      expect { described_class.perform_now(event.id) }
        .to have_enqueued_job(PushNotificationJob).with(event.id)
    end
  end

  describe "when an unexpected error occurs during capture" do
    before do
      stub_const("ENV", ENV.to_hash.merge(
        "REOLINK_HOST"     => "10.27.140.51",
        "REOLINK_USERNAME" => "admin",
        "REOLINK_PASSWORD" => "this4you"
      ))
      allow_any_instance_of(ReoLink::Client).to receive(:snapshot).and_raise(StandardError, "boom")
    end

    it "logs and swallows the error rather than raising" do
      expect { described_class.perform_now(event.id) }.not_to raise_error
    end

    it "still enqueues the PushNotificationJob" do
      expect { described_class.perform_now(event.id) }
        .to have_enqueued_job(PushNotificationJob).with(event.id)
    end
  end
end
