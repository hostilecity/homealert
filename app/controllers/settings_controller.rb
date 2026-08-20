class SettingsController < ApplicationController
  layout "authenticated"

  def index
    @notification_preference = NotificationPreference.for_user(current_user)
    @push_subscription        = current_user.push_subscriptions.order(created_at: :desc).first
  end

  def update_notification_preferences
    preference = NotificationPreference.for_user(current_user)
    preference.update!(preference_params)
    head :ok
  rescue ActionController::ParameterMissing, ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def preference_params
    params.require(:preference).permit(:doorbell_pressed, :motion_detected)
  end
end
