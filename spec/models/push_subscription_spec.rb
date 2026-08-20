require "rails_helper"

RSpec.describe PushSubscription, type: :model do
  subject(:subscription) { build(:push_subscription) }

  # ---------------------------------------------------------------------------
  # Associations
  # ---------------------------------------------------------------------------
  describe "associations" do
    it "belongs to a user" do
      association = described_class.reflect_on_association(:user)
      expect(association.macro).to eq(:belongs_to)
    end

    it "is invalid without a user" do
      subscription.user = nil
      expect(subscription).not_to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------
  describe "validations" do
    it "is valid with valid attributes" do
      expect(subscription).to be_valid
    end

    describe "endpoint" do
      it "requires presence" do
        subscription.endpoint = nil
        expect(subscription).not_to be_valid
        expect(subscription.errors[:endpoint]).to include("can't be blank")
      end

      it "requires uniqueness" do
        existing = create(:push_subscription)
        subscription.endpoint = existing.endpoint
        expect(subscription).not_to be_valid
        expect(subscription.errors[:endpoint]).to include("has already been taken")
      end

      it "allows different endpoints for the same user" do
        user = create(:user)
        create(:push_subscription, user: user)
        another = build(:push_subscription, user: user)
        expect(another).to be_valid
      end
    end

    describe "p256dh_key" do
      it "requires presence" do
        subscription.p256dh_key = nil
        expect(subscription).not_to be_valid
        expect(subscription.errors[:p256dh_key]).to include("can't be blank")
      end
    end

    describe "auth_key" do
      it "requires presence" do
        subscription.auth_key = nil
        expect(subscription).not_to be_valid
        expect(subscription.errors[:auth_key]).to include("can't be blank")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #web_push_keys
  # ---------------------------------------------------------------------------
  describe "#web_push_keys" do
    let(:p256dh) { Faker::Crypto.sha256 }
    let(:auth)   { Faker::Crypto.md5 }

    subject(:subscription) { build(:push_subscription, p256dh_key: p256dh, auth_key: auth) }

    it "returns a hash" do
      expect(subscription.web_push_keys).to be_a(Hash)
    end

    it "contains the p256dh key" do
      expect(subscription.web_push_keys[:p256dh]).to eq(p256dh)
    end

    it "contains the auth key" do
      expect(subscription.web_push_keys[:auth]).to eq(auth)
    end

    it "returns exactly two keys" do
      expect(subscription.web_push_keys.keys).to contain_exactly(:p256dh, :auth)
    end
  end
end
