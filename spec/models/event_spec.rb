require "rails_helper"

RSpec.describe Event, type: :model do
  subject(:event) { build(:event) }

  # ---------------------------------------------------------------------------
  # Constants
  # ---------------------------------------------------------------------------
  describe "TYPES" do
    it "contains exactly doorbell_pressed and motion_detected" do
      expect(described_class::TYPES).to contain_exactly("doorbell_pressed", "motion_detected")
    end

    it "is frozen" do
      expect(described_class::TYPES).to be_frozen
    end
  end

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  describe "validations" do
    it "is valid with valid attributes" do
      expect(event).to be_valid
    end

    describe "event_type" do
      it "requires presence" do
        event.event_type = nil
        expect(event).not_to be_valid
        expect(event.errors[:event_type]).to include("can't be blank")
      end

      it "must be a known type" do
        event.event_type = "unknown_type"
        expect(event).not_to be_valid
        expect(event.errors[:event_type]).to include("is not included in the list")
      end

      it "accepts doorbell_pressed" do
        event.event_type = "doorbell_pressed"
        expect(event).to be_valid
      end

      it "accepts motion_detected" do
        event.event_type = "motion_detected"
        expect(event).to be_valid
      end
    end

    describe "device_name" do
      it "requires presence" do
        event.device_name = nil
        expect(event).not_to be_valid
        expect(event.errors[:device_name]).to include("can't be blank")
      end
    end

    describe "device_id" do
      it "requires presence" do
        event.device_id = nil
        expect(event).not_to be_valid
        expect(event.errors[:device_id]).to include("can't be blank")
      end
    end

    describe "occurred_at" do
      it "requires presence" do
        event.occurred_at = nil
        expect(event).not_to be_valid
        expect(event.errors[:occurred_at]).to include("can't be blank")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Scopes
  # ---------------------------------------------------------------------------
  describe "scopes" do
    describe ".recent" do
      it "orders events by occurred_at descending" do
        older  = create(:event, occurred_at: 2.hours.ago)
        newer  = create(:event, occurred_at: 1.hour.ago)
        newest = create(:event, occurred_at: Time.current)

        expect(described_class.recent.to_a).to eq([newest, newer, older])
      end
    end

    describe ".today" do
      it "returns events that occurred today" do
        today_event     = create(:event, occurred_at: Time.current)
        yesterday_event = create(:event, occurred_at: 1.day.ago)

        expect(described_class.today).to include(today_event)
        expect(described_class.today).not_to include(yesterday_event)
      end

      it "includes events timestamped in the future (scope covers beginning_of_day onward)" do
        # The scope uses `beginning_of_day..` (endless range), which includes any occurred_at
        # from midnight today forward. This is intentional — it counts all events for today's
        # date including those that arrive slightly ahead of the server clock.
        future_event = create(:event, occurred_at: 1.day.from_now)
        expect(described_class.today).to include(future_event)
      end
    end

    describe ".doorbell_pressed" do
      it "returns only doorbell_pressed events" do
        doorbell = create(:event, :doorbell_pressed)
        motion   = create(:event, :motion_detected)

        expect(described_class.doorbell_pressed).to include(doorbell)
        expect(described_class.doorbell_pressed).not_to include(motion)
      end
    end

    describe ".motion_detected" do
      it "returns only motion_detected events" do
        doorbell = create(:event, :doorbell_pressed)
        motion   = create(:event, :motion_detected)

        expect(described_class.motion_detected).to include(motion)
        expect(described_class.motion_detected).not_to include(doorbell)
      end
    end
  end
end
