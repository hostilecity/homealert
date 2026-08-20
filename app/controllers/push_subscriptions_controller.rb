class PushSubscriptionsController < ApplicationController
  # Allowlist: push endpoints must be HTTPS and must not target private/
  # loopback/link-local addresses to prevent SSRF via forged subscriptions.
  PRIVATE_ADDRESS_PATTERN = /
    \Ahttps?:\/\/                             # any scheme (caught below for http)
    (?:
      localhost |
      127\. |
      0\.0\.0\.0 |
      10\. |
      172\.(?:1[6-9]|2\d|3[01])\. |
      192\.168\. |
      169\.254\. |
      \[::1\] |
      \[fc|fd                                 # IPv6 ULA
    )
  /xi

  def create
    endpoint = subscription_params[:endpoint]

    unless valid_endpoint?(endpoint)
      return render json: { error: "Invalid push endpoint." }, status: :unprocessable_entity
    end

    # An endpoint is globally unique. If another user owns it (e.g. after
    # account switching without unsubscribing), reassign it to the current user
    # so they receive notifications and the old record is cleaned up.
    subscription = PushSubscription.find_or_initialize_by(endpoint: endpoint)
    subscription.assign_attributes(
      user:         current_user,
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

  def valid_endpoint?(endpoint)
    uri = URI.parse(endpoint)
    return false unless uri.scheme == "https"
    return false if uri.host.blank?
    return false if endpoint.match?(PRIVATE_ADDRESS_PATTERN)

    true
  rescue URI::InvalidURIError
    false
  end

  def subscription_params
    params.require(:subscription).permit(:endpoint, :p256dh_key, :auth_key, :device_label)
  end
end
