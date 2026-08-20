require "rails_helper"

RSpec.describe NotificationPreference, type: :model do
  subject(:preference) { build(:notification_preference) }

  # ---------------------------------------------------------------------------
  # Associations
  # ---------------------------------------------------------------------------
  describe "associations" do
    it "belongs to a user" do
      association = described_class.reflect_on_association(:user)
      expect(association.macro).to eq(:belongs_to)
    end

    it "is invalid without a user" do
      preference.user = nil
      expect(preference).not_to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  describe "validations" do
    it "is valid with valid attributes" do
      expect(preference).to be_valid
    end

    describe "doorbell_pressed" do
      it "accepts true" do
        preference.doorbell_pressed = true
        expect(preference).to be_valid
      end

      it "accepts false" do
        preference.doorbell_pressed = false
        expect(preference).to be_valid
      end

      it "rejects nil" do
        preference.doorbell_pressed = nil
        expect(preference).not_to be_valid
        expect(preference.errors[:doorbell_pressed]).to include("is not included in the list")
      end
    end

    describe "motion_detected" do
      it "accepts true" do
        preference.motion_detected = true
        expect(preference).to be_valid
      end

      it "accepts false" do
        preference.motion_detected = false
        expect(preference).to be_valid
      end

      it "rejects nil" do
        preference.motion_detected = nil
        expect(preference).not_to be_valid
        expect(preference.errors[:motion_detected]).to include("is not included in the list")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # .for_user
  # ---------------------------------------------------------------------------
  describe ".for_user" do
    let(:user) { create(:user) }

    context "when no preference exists for the user" do
      it "creates a new preference" do
        expect { described_class.for_user(user) }.to change(described_class, :count).by(1)
      end

      it "returns the new preference associated with the user" do
        pref = described_class.for_user(user)
        expect(pref.user).to eq(user)
      end
    end

    context "when a preference already exists for the user" do
      let!(:existing) { create(:notification_preference, user: user) }

      it "does not create another preference" do
        expect { described_class.for_user(user) }.not_to change(described_class, :count)
      end

      it "returns the existing preference" do
        expect(described_class.for_user(user)).to eq(existing)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #enabled_for?
  # ---------------------------------------------------------------------------
  describe "#enabled_for?" do
    context "when all notifications are enabled" do
      subject(:preference) { build(:notification_preference, doorbell_pressed: true, motion_detected: true) }

      it "returns true for doorbell_pressed" do
        expect(preference.enabled_for?("doorbell_pressed")).to be true
      end

      it "returns true for motion_detected" do
        expect(preference.enabled_for?("motion_detected")).to be true
      end
    end

    context "when doorbell_pressed is disabled" do
      subject(:preference) { build(:notification_preference, :doorbell_only, doorbell_pressed: false) }

      it "returns false for doorbell_pressed" do
        expect(preference.enabled_for?("doorbell_pressed")).to be false
      end
    end

    context "when motion_detected is disabled" do
      subject(:preference) { build(:notification_preference, :motion_only, motion_detected: false) }

      it "returns false for motion_detected" do
        expect(preference.enabled_for?("motion_detected")).to be false
      end
    end

    context "with an unknown event type" do
      it "returns false" do
        expect(preference.enabled_for?("unknown_event")).to be false
      end

      it "returns false for nil" do
        expect(preference.enabled_for?(nil)).to be false
      end

      it "returns false for an empty string" do
        expect(preference.enabled_for?("")).to be false
      end
    end
  end
end
