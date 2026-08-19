class OmniauthCallbacksController < ApplicationController
  skip_before_action :require_authentication

  def google_oauth2
    user = User.from_omniauth(request.env["omniauth.auth"])
    reset_session
    session[:user_id] = user.id
    redirect_to root_path, notice: "Signed in as #{user.name}."
  rescue User::NotAllowedError
    Rails.logger.warn("Blocked unauthorized OAuth login attempt")
    redirect_to login_path, alert: "Your account is not authorized to access HomeAlert."
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("OAuth login failed: #{e.message}")
    redirect_to login_path, alert: "Sign in failed. Please try again."
  end
end
