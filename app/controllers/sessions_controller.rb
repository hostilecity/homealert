class SessionsController < ApplicationController
  skip_before_action :require_authentication, only: %i[new failure]

  def new
    redirect_to root_path if current_user
  end

  def destroy
    reset_session
    redirect_to login_path, notice: "You have been signed out."
  end

  def failure
    redirect_to login_path, alert: "Authentication failed. Please try again."
  end
end
