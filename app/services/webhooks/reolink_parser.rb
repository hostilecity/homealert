module Webhooks
  # Parses incoming webhook payloads from ReoLink Video Doorbell devices.
  #
  # ReoLink sends a form-encoded or JSON POST with the following fields:
  #   action / Action / cmd  — event type identifier
  #   channel                — zero-based camera channel index
  #   device_id / host       — device identifier (varies by firmware)
  #   time / timestamp       — Unix timestamp of the event (optional)
  #
  # Supported action values (case-insensitive):
  #   "Visitor", "visitor"   → doorbell_pressed
  #   "MD", "Motion"         → motion_detected
  class ReoLinkParser < ParserBase
    DEVICE_NAME = "ReoLink Video Doorbell"

    EVENT_TYPE_MAP = {
      "visitor" => "doorbell_pressed",
      "md"      => "motion_detected",
      "motion"  => "motion_detected"
    }.freeze

    def parse
      event_type = resolve_event_type!
      occurred_at = resolve_occurred_at

      {
        event_type:  event_type,
        device_name: device_name,
        device_id:   resolve_device_id,
        occurred_at: occurred_at
      }
    end

    private

    def resolve_event_type!
      raw = payload["action"] || payload["Action"] || payload["cmd"]
      mapped = EVENT_TYPE_MAP[raw.to_s.downcase]

      raise UnknownEventError, "Unrecognised ReoLink action: #{raw.inspect}" unless mapped

      mapped
    end

    def resolve_device_id
      payload["device_id"] || payload["host"] || payload["channel"]&.to_s || "unknown"
    end

    def device_name
      channel = payload["channel"]
      channel.present? ? "#{DEVICE_NAME} (channel #{channel})" : DEVICE_NAME
    end

    def resolve_occurred_at
      raw = payload["time"] || payload["timestamp"]
      return Time.current unless raw.present?

      Time.zone.at(raw.to_i)
    rescue ArgumentError
      Time.current
    end
  end
end
