class PushSubscriptionsController < ApplicationController
  LEGACY_FCM_ENDPOINT = "https://fcm.googleapis.com/fcm/send/"

  def create
    endpoint = subscription_params[:endpoint]

    if endpoint.start_with?(LEGACY_FCM_ENDPOINT)
      return render json: { error: "Legacy FCM endpoint rejected — please clear site data in your browser and subscribe again." },
                    status: :unprocessable_entity
    end

    subscription = current_user.push_subscriptions.find_or_initialize_by(endpoint: endpoint)
    subscription.assign_attributes(
      p256dh_key:   subscription_params[:p256dh_key],
      auth_key:     subscription_params[:auth_key],
      device_label: subscription_params[:device_label]
    )
    subscription.save!
    head :created
  rescue ActionController::ParameterMissing, ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    subscription = current_user.push_subscriptions.find(params[:id])
    subscription.destroy!
    head :no_content
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  private

  def subscription_params
    params.require(:subscription).permit(:endpoint, :p256dh_key, :auth_key, :device_label)
  end
end
