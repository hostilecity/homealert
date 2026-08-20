require "rails_helper"

RSpec.describe "OmniauthCallbacks", type: :request do
  # Enable OmniAuth test mode so GET /auth/google_oauth2/callback bypasses
  # CSRF protection and injects the mock auth hash into the rack env, which
  # the controller then passes to User.from_omniauth.
  before do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid:      "google_uid_test",
      info:     { email: "test@example.com", name: "Test User", image: nil }
    )
  end

  after do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  describe "GET /auth/google_oauth2/callback" do
    context "when OAuth succeeds" do
      let(:user) { create(:user) }

      before do
        allow(User).to receive(:from_omniauth).and_return(user)
      end

      it "redirects to root" do
        get "/auth/google_oauth2/callback"
        expect(response).to redirect_to(root_path)
      end

      it "sets a signed-in notice" do
        get "/auth/google_oauth2/callback"
        expect(flash[:notice]).to eq("Signed in as #{user.name}.")
      end
    end

    context "when User::NotAllowedError is raised" do
      before do
        allow(User).to receive(:from_omniauth).and_raise(User::NotAllowedError, "not allowed")
      end

      it "redirects to login" do
        get "/auth/google_oauth2/callback"
        expect(response).to redirect_to(login_path)
      end

      it "sets an alert" do
        get "/auth/google_oauth2/callback"
        expect(flash[:alert]).to eq("Your account is not authorized to access HomeAlert.")
      end
    end

    context "when ActiveRecord::RecordInvalid is raised" do
      before do
        invalid_record = build(:user)
        invalid_record.errors.add(:base, "some db error")
        allow(User).to receive(:from_omniauth)
          .and_raise(ActiveRecord::RecordInvalid.new(invalid_record))
      end

      it "redirects to login" do
        get "/auth/google_oauth2/callback"
        expect(response).to redirect_to(login_path)
      end

      it "sets an alert" do
        get "/auth/google_oauth2/callback"
        expect(flash[:alert]).to eq("Sign in failed. Please try again.")
      end
    end
  end
end
