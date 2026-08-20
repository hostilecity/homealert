class PushNotificationJob < ApplicationJob
  queue_as :default

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

    PushSubscription.find_each do |subscription|
      next unless NotificationPreference.for_user(subscription.user).enabled_for?(event.event_type)

      begin
        WebPush.payload_send(
          endpoint: subscription.endpoint,
          message:  payload,
          p256dh:   subscription.p256dh_key,
          auth:     subscription.auth_key,
          vapid:    vapid
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
      end
    end
  end

  private

  def notification_title(event)
    case event.event_type
    when "doorbell_pressed" then "Doorbell pressed"
    when "motion_detected"  then "Motion detected"
    else event.event_type.humanize
    end
  end
end
