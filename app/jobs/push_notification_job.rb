class PushNotificationJob < ApplicationJob
  queue_as :default

  def perform(event_id)
    event = Event.find_by(id: event_id)
    return unless event

    payload = JSON.generate(
      title: notification_title(event),
      body:  event.device_name,
      path:  "/"
    )

    vapid = {
      subject:    "mailto:admin@homealert.local",
      public_key: ENV.fetch("VAPID_PUBLIC_KEY"),
      private_key: ENV.fetch("VAPID_PRIVATE_KEY")
    }

    PushSubscription.find_each do |subscription|
      next unless NotificationPreference.for_user(subscription.user).enabled_for?(event.event_type)

      WebPush.payload_send(
        endpoint: subscription.endpoint,
        message:  payload,
        p256dh:   subscription.p256dh_key,
        auth:     subscription.auth_key,
        vapid:    vapid
      )
    rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription
      subscription.destroy
    rescue WebPush::Error => e
      Rails.logger.error("WebPush failed for subscription #{subscription.id}: #{e.message}")
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
