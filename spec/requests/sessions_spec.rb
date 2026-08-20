require "rails_helper"

RSpec.describe "Sessions", type: :request do
  describe "GET /login" do
    context "when not signed in" do
      it "returns 200" do
        get login_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "when already signed in" do
      it "redirects to root" do
        user = create(:user)
        # Stub before the request rather than using sign_in, because
        # AuthHelpers#sign_in tries to set session[:user_id] before any
        # request has been made, which raises a NoMethodError in request specs.
        allow_any_instance_of(ApplicationController)
          .to receive(:current_user).and_return(user)
        allow_any_instance_of(ApplicationController)
          .to receive(:require_authentication)

        get login_path
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe "POST /logout" do
    it "resets the session and redirects to login with notice" do
      user = create(:user)
      allow_any_instance_of(ApplicationController)
        .to receive(:current_user).and_return(user)
      allow_any_instance_of(ApplicationController)
        .to receive(:require_authentication)

      post logout_path
      expect(response).to redirect_to(login_path)
      expect(flash[:notice]).to eq("You have been signed out.")
    end
  end

  describe "GET /auth/failure" do
    it "redirects to login with an alert" do
      get "/auth/failure"
      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to eq("Authentication failed. Please try again.")
    end
  end
end
