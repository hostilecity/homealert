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

    retire_previous_endpoint(subscription)

    render json: {
      id:              subscription.id,
      endpoint_digest: subscription.endpoint_digest,
      device_label:    subscription.device_label
    }, status: :created
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

  # A browser may rotate the endpoint of an existing subscription (permission
  # re-grant, push service migration, PWA reinstall). Without this the old row
  # lingers as a phantom device and wastes a delivery attempt on every event.
  def retire_previous_endpoint(subscription)
    previous = params[:subscription][:previous_endpoint].presence
    return if previous.blank? || previous == subscription.endpoint

    current_user.push_subscriptions.where(endpoint: previous).destroy_all
  end

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
    params.require(:subscription)
          .permit(:endpoint, :p256dh_key, :auth_key, :device_label, :previous_endpoint)
  end
end
