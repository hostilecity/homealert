module Webhooks
  # Parses incoming webhook payloads from OpenVPN client-connect scripts.
  #
  # The script at script/vpn_webhook.sh posts a JSON body with the following
  # shape (all values are strings provided by OpenVPN's environment):
  #
  #   {
  #     "event":          "vpn_login",
  #     "username":       "$username",
  #     "common_name":    "$common_name",
  #     "source_ip":      "$trusted_ip",
  #     "timestamp_unix": "$time_unix"
  #   }
  #
  # The parsed result maps to a single event type:
  #   "vpn_login" → vpn_login
  class VpnLoginParser < ParserBase
    SUPPORTED_EVENT = "vpn_login"

    def parse
      validate_event_type!

      {
        event_type:  SUPPORTED_EVENT,
        device_name: resolve_device_name,
        device_id:   resolve_device_id,
        occurred_at: resolve_occurred_at
      }
    end

    private

    def validate_event_type!
      raw = payload["event"].to_s.strip
      return if raw == SUPPORTED_EVENT

      raise UnknownEventError, "Unrecognised VPN event: #{raw.inspect}"
    end

    def resolve_device_name
      username    = payload["username"].presence
      common_name = payload["common_name"].presence

      if username && common_name && username != common_name
        "#{username} (#{common_name})"
      elsif username
        username
      elsif common_name
        common_name
      else
        "Unknown VPN user"
      end
    end

    def resolve_device_id
      payload["source_ip"].presence || "unknown"
    end

    def resolve_occurred_at
      raw = payload["timestamp_unix"]
      return Time.current unless raw.present?

      Time.zone.at(Integer(raw))
    rescue ArgumentError, TypeError
      Time.current
    end
  end
end
