require "rails_helper"

RSpec.describe "Pages", type: :request do
  describe "GET /privacy" do
    it "is accessible without authentication" do
      get privacy_path
      expect(response).to have_http_status(:ok)
    end

    it "does not redirect to login" do
      get privacy_path
      expect(response).not_to redirect_to(login_path)
    end
  end
end
