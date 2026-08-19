module Webhooks
  # Parses incoming webhook payloads from ReoLink Video Doorbell devices.
  #
  # ReoLink posts a JSON body with a top-level "alarm" object:
  #
  #   {
  #     "alarm": {
  #       "alarmTime":   "2026-08-17T17:04:34.000+0000",
  #       "channel":     0,
  #       "channelName": "doorbell",
  #       "device":      "doorbell",
  #       "deviceModel": "Reolink Video Doorbell WiFi",
  #       "message":     "...",
  #       "name":        "...",
  #       "title":       "...",
  #       "type":        "VISITOR" | "PEOPLE" | ...
  #     }
  #   }
  #
  # Supported type values (case-insensitive):
  #   "VISITOR" → doorbell_pressed
  #   "PEOPLE"  → motion_detected
  class ReoLinkParser < ParserBase
    EVENT_TYPE_MAP = {
      "visitor" => "doorbell_pressed",
      "people"  => "motion_detected"
    }.freeze

    def parse
      {
        event_type:  resolve_event_type!,
        device_name: resolve_device_name,
        device_id:   resolve_device_id,
        occurred_at: resolve_occurred_at
      }
    end

    private

    def alarm
      payload["alarm"] || raise(UnknownEventError, "Missing 'alarm' key in ReoLink payload")
    end

    def resolve_event_type!
      raw = alarm["type"]
      mapped = EVENT_TYPE_MAP[raw.to_s.downcase]

      raise UnknownEventError, "Unrecognised ReoLink type: #{raw.inspect}" unless mapped

      mapped
    end

    def resolve_device_name
      model   = alarm["deviceModel"].presence || "ReoLink Device"
      channel = alarm["channelName"].presence

      channel ? "#{model} — #{channel}" : model
    end

    def resolve_device_id
      alarm["device"].presence || alarm["channel"]&.to_s || "unknown"
    end

    def resolve_occurred_at
      raw = alarm["alarmTime"]
      return Time.current unless raw.present?

      Time.zone.parse(raw)
    rescue ArgumentError, TypeError
      Time.current
    end
  end
end
