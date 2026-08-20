require "rails_helper"

RSpec.describe User, type: :model do
  subject(:user) { build(:user) }

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  describe "validations" do
    it "is valid with valid attributes" do
      expect(user).to be_valid
    end

    describe "google_uid" do
      it "requires presence" do
        user.google_uid = nil
        expect(user).not_to be_valid
        expect(user.errors[:google_uid]).to include("can't be blank")
      end

      it "requires uniqueness" do
        create(:user, google_uid: "duplicate_uid")
        user.google_uid = "duplicate_uid"
        expect(user).not_to be_valid
        expect(user.errors[:google_uid]).to include("has already been taken")
      end
    end

    describe "email" do
      it "requires presence" do
        user.email = nil
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include("can't be blank")
      end

      it "requires uniqueness" do
        existing = create(:user)
        user.email = existing.email
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include("has already been taken")
      end
    end

    describe "name" do
      it "requires presence" do
        user.name = nil
        expect(user).not_to be_valid
        expect(user.errors[:name]).to include("can't be blank")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Associations
  # ---------------------------------------------------------------------------
  describe "associations" do
    it "has many push_subscriptions" do
      association = described_class.reflect_on_association(:push_subscriptions)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:dependent]).to eq(:destroy)
    end

    it "has one notification_preference" do
      association = described_class.reflect_on_association(:notification_preference)
      expect(association.macro).to eq(:has_one)
      expect(association.options[:dependent]).to eq(:destroy)
    end

    it "destroys push_subscriptions when user is destroyed" do
      user = create(:user)
      create(:push_subscription, user: user)
      expect { user.destroy }.to change(PushSubscription, :count).by(-1)
    end

    it "destroys notification_preference when user is destroyed" do
      user = create(:user)
      create(:notification_preference, user: user)
      expect { user.destroy }.to change(NotificationPreference, :count).by(-1)
    end
  end

  # ---------------------------------------------------------------------------
  # .allowlist
  # ---------------------------------------------------------------------------
  describe ".allowlist" do
    context "when ALLOWED_EMAILS is not set" do
      it "returns an empty array" do
        stub_const("ENV", ENV.to_h.merge("ALLOWED_EMAILS" => ""))
        expect(described_class.allowlist).to eq([])
      end
    end

    context "when ALLOWED_EMAILS contains a single email" do
      it "returns an array with that email downcased" do
        stub_const("ENV", ENV.to_h.merge("ALLOWED_EMAILS" => "Admin@Example.com"))
        expect(described_class.allowlist).to eq([ "admin@example.com" ])
      end
    end

    context "when ALLOWED_EMAILS contains multiple comma-separated emails" do
      it "strips whitespace, downcases, and rejects empty entries" do
        stub_const("ENV", ENV.to_h.merge("ALLOWED_EMAILS" => " Alice@foo.com , BOB@BAR.COM ,, charlie@baz.org "))
        expect(described_class.allowlist).to eq(%w[alice@foo.com bob@bar.com charlie@baz.org])
      end
    end
  end

  # ---------------------------------------------------------------------------
  # .allowed?
  # ---------------------------------------------------------------------------
  describe ".allowed?" do
    before do
      stub_const("ENV", ENV.to_h.merge("ALLOWED_EMAILS" => "allowed@example.com,other@example.com"))
    end

    it "returns true for an email on the allowlist" do
      expect(described_class.allowed?("allowed@example.com")).to be true
    end

    it "is case-insensitive" do
      expect(described_class.allowed?("ALLOWED@EXAMPLE.COM")).to be true
    end

    it "returns false for an email not on the allowlist" do
      expect(described_class.allowed?("stranger@example.com")).to be false
    end

    it "returns false for nil" do
      expect(described_class.allowed?(nil)).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # .from_omniauth
  # ---------------------------------------------------------------------------
  describe ".from_omniauth" do
    let(:allowed_email) { "user@example.com" }
    let(:auth) do
      OmniAuth::AuthHash.new(
        uid: "google_uid_999",
        info: {
          email: allowed_email,
          name: "Test User",
          image: "https://lh3.googleusercontent.com/photo.jpg"
        }
      )
    end

    before do
      stub_const("ENV", ENV.to_h.merge("ALLOWED_EMAILS" => allowed_email))
    end

    context "when the email is on the allowlist" do
      it "creates a new user when one does not exist" do
        expect { described_class.from_omniauth(auth) }.to change(User, :count).by(1)
      end

      it "returns the created user" do
        result = described_class.from_omniauth(auth)
        expect(result).to be_a(User)
        expect(result).to be_persisted
      end

      it "sets attributes from auth hash" do
        result = described_class.from_omniauth(auth)
        expect(result.google_uid).to eq("google_uid_999")
        expect(result.email).to eq(allowed_email)
        expect(result.name).to eq("Test User")
        expect(result.avatar_url).to eq("https://lh3.googleusercontent.com/photo.jpg")
      end

      it "finds and updates an existing user with the same google_uid" do
        existing = create(:user, google_uid: "google_uid_999", email: allowed_email)
        result = described_class.from_omniauth(auth)
        expect(User.count).to eq(1)
        expect(result.id).to eq(existing.id)
        expect(result.name).to eq("Test User")
      end

      it "normalises the email to lowercase" do
        auth.info.email = "User@Example.COM"
        stub_const("ENV", ENV.to_h.merge("ALLOWED_EMAILS" => "user@example.com"))
        result = described_class.from_omniauth(auth)
        expect(result.email).to eq("user@example.com")
      end
    end

    context "when the email is not on the allowlist" do
      before do
        stub_const("ENV", ENV.to_h.merge("ALLOWED_EMAILS" => "someone_else@example.com"))
      end

      it "raises User::NotAllowedError" do
        expect { described_class.from_omniauth(auth) }.to raise_error(User::NotAllowedError)
      end

      it "does not create a user record" do
        expect { described_class.from_omniauth(auth) rescue nil }.not_to change(User, :count)
      end
    end

    context "when the user record is invalid" do
      it "raises ActiveRecord::RecordInvalid" do
        # Force a validation failure by having a conflicting email on a
        # different google_uid after initialization.
        allow_any_instance_of(User).to receive(:save!).and_raise(ActiveRecord::RecordInvalid)
        expect { described_class.from_omniauth(auth) }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # User::NotAllowedError
  # ---------------------------------------------------------------------------
  describe "User::NotAllowedError" do
    it "is defined as a subclass of StandardError" do
      expect(User::NotAllowedError.ancestors).to include(StandardError)
    end

    it "can be raised and rescued" do
      expect { raise User::NotAllowedError, "not allowed" }
        .to raise_error(User::NotAllowedError, "not allowed")
    end
  end
end
