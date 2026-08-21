class PushNotificationJob < ApplicationJob
  queue_as :default

  # Keep an undelivered alert queued at the push service while a phone is
  # offline, but drop it once it is no longer timely.
  TTL_SECONDS = 5.minutes.to_i

  def perform(event_id)
    event = Event.find_by(id: event_id)
    return unless event

    vapid_public_key  = ENV["VAPID_PUBLIC_KEY"].presence
    vapid_private_key = ENV["VAPID_PRIVATE_KEY"].presence

    unless vapid_public_key && vapid_private_key
      Rails.logger.error("PushNotificationJob: VAPID_PUBLIC_KEY or VAPID_PRIVATE_KEY not set — skipping dispatch")
      return
    end

    payload = JSON.generate(
      title: notification_title(event),
      body:  event.device_name,
      path:  "/"
    )

    vapid = {
      subject:     "mailto:admin@homealert.local",
      public_key:  vapid_public_key,
      private_key: vapid_private_key
    }

    # A user may have many devices registered; every one of them must be
    # attempted, and a failure on one must never abort delivery to the rest.
    PushSubscription.includes(:user).find_each do |subscription|
      next unless enabled_for?(subscription.user, event.event_type)

      deliver(subscription, payload, vapid, event)
    end
  end

  private

  def deliver(subscription, payload, vapid, event)
    WebPush.payload_send(
      endpoint: subscription.endpoint,
      message:  payload,
      p256dh:   subscription.p256dh_key,
      auth:     subscription.auth_key,
      vapid:    vapid,
      ttl:      TTL_SECONDS,
      urgency:  "high"
    )
    Rails.logger.info("PushNotificationJob: sent #{event.event_type} to subscription #{subscription.id}")
  rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription
    Rails.logger.info("PushNotificationJob: removing stale subscription #{subscription.id}")
    subscription.destroy
  rescue WebPush::ResponseError => e
    Rails.logger.error("PushNotificationJob: WebPush response error for subscription #{subscription.id}: #{e.message} (#{e.response&.code})")
  rescue WebPush::Error => e
    Rails.logger.error("PushNotificationJob: WebPush error for subscription #{subscription.id}: #{e.message}")
  rescue ArgumentError => e
    Rails.logger.error("PushNotificationJob: invalid VAPID or subscription keys — #{e.message}")
  rescue StandardError => e
    # Only swallow errors that are clearly network/transport-layer failures so
    # that the remaining devices still receive the alert. Re-raise anything
    # unexpected (programming errors, database failures, etc.) so Active Job /
    # Solid Queue can retry or dead-letter the job.
    raise unless e.is_a?(Net::OpenTimeout)     ||
                 e.is_a?(Net::ReadTimeout)      ||
                 e.is_a?(Errno::ECONNREFUSED)   ||
                 e.is_a?(Errno::ECONNRESET)     ||
                 e.is_a?(SocketError)           ||
                 e.is_a?(OpenSSL::SSL::SSLError)

    Rails.logger.error("PushNotificationJob: delivery failed for subscription #{subscription.id}: #{e.class} #{e.message}")
  end

  def enabled_for?(user, event_type)
    @preferences ||= {}
    preference = (@preferences[user.id] ||= NotificationPreference.for_user(user))
    preference.enabled_for?(event_type)
  end

  def notification_title(event)
    case event.event_type
    when "doorbell_pressed" then "Doorbell pressed"
    when "motion_detected"  then "Motion detected"
    else event.event_type.humanize
    end
  end
end
