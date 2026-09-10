require "rails_helper"

RSpec.describe SnapshotRetentionJob, type: :job do
  let(:image) { Rails.root.join("spec/fixtures/files/snapshot.jpg") }

  def attach_snapshot(event, attached_at:)
    event.snapshot.attach(io: File.open(image), filename: "snapshot.jpg", content_type: "image/jpeg")
    event.snapshot.attachment.update_column(:created_at, attached_at)
  end

  describe "with the default retention window" do
    it "purges snapshots older than 30 days" do
      old_event = create(:event)
      attach_snapshot(old_event, attached_at: 31.days.ago)

      described_class.perform_now

      expect(old_event.reload.snapshot).not_to be_attached
    end

    it "keeps snapshots within the retention window" do
      recent_event = create(:event)
      attach_snapshot(recent_event, attached_at: 1.day.ago)

      described_class.perform_now

      expect(recent_event.reload.snapshot).to be_attached
    end

    it "logs how many snapshots were purged" do
      old_event = create(:event)
      attach_snapshot(old_event, attached_at: 31.days.ago)

      allow(Rails.logger).to receive(:info).and_call_original
      described_class.perform_now
      expect(Rails.logger).to have_received(:info).with(/purged 1 snapshot/)
    end

    it "does not log a purge summary when nothing needed purging" do
      recent_event = create(:event)
      attach_snapshot(recent_event, attached_at: 1.day.ago)

      allow(Rails.logger).to receive(:info).and_call_original
      described_class.perform_now
      expect(Rails.logger).not_to have_received(:info).with(/purged/)
    end
  end

  describe "when SNAPSHOT_RETENTION_DAYS is customized" do
    it "honors a shorter retention window" do
      stub_const("ENV", ENV.to_hash.merge("SNAPSHOT_RETENTION_DAYS" => "1"))

      event = create(:event)
      attach_snapshot(event, attached_at: 2.days.ago)

      described_class.perform_now

      expect(event.reload.snapshot).not_to be_attached
    end
  end

  describe "when SNAPSHOT_RETENTION_DAYS is 0" do
    it "keeps snapshots indefinitely" do
      stub_const("ENV", ENV.to_hash.merge("SNAPSHOT_RETENTION_DAYS" => "0"))

      event = create(:event)
      attach_snapshot(event, attached_at: 5.years.ago)

      described_class.perform_now

      expect(event.reload.snapshot).to be_attached
    end
  end

  describe "when SNAPSHOT_RETENTION_DAYS is invalid" do
    it "falls back to the default retention window rather than raising" do
      stub_const("ENV", ENV.to_hash.merge("SNAPSHOT_RETENTION_DAYS" => "not-a-number"))

      old_event = create(:event)
      attach_snapshot(old_event, attached_at: 31.days.ago)

      expect { described_class.perform_now }.not_to raise_error
      expect(old_event.reload.snapshot).not_to be_attached
    end
  end
end
