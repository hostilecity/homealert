require "rails_helper"

RSpec.describe Webhooks::VpnLoginParser do
  subject(:parser) { described_class.new(payload) }

  let(:base_payload) do
    {
      "event"          => "vpn_login",
      "username"       => "rtulino",
      "common_name"    => "ryans-macbook",
      "source_ip"      => "203.0.113.42",
      "timestamp_unix" => "1756310400"
    }
  end

  let(:payload) { base_payload }

  # ------------------------------------------------------------------ #
  # event_type validation                                                #
  # ------------------------------------------------------------------ #
  describe "#parse event_type" do
    it 'returns "vpn_login" for the expected event value' do
      expect(parser.parse[:event_type]).to eq("vpn_login")
    end

    it "raises UnknownEventError for an unrecognised event value" do
      payload["event"] = "vpn_logout"
      expect { parser.parse }.to raise_error(Webhooks::UnknownEventError, /Unrecognised VPN event/)
    end

    it "raises UnknownEventError when event key is missing" do
      payload.delete("event")
      expect { parser.parse }.to raise_error(Webhooks::UnknownEventError)
    end

    it "raises UnknownEventError when event is nil" do
      payload["event"] = nil
      expect { parser.parse }.to raise_error(Webhooks::UnknownEventError)
    end
  end

  # ------------------------------------------------------------------ #
  # device_name resolution (username + common_name)                     #
  # ------------------------------------------------------------------ #
  describe "#parse device_name" do
    it "combines username and common_name when both are present and different" do
      expect(parser.parse[:device_name]).to eq("rtulino (ryans-macbook)")
    end

    it "uses only username when common_name is absent" do
      payload.delete("common_name")
      expect(parser.parse[:device_name]).to eq("rtulino")
    end

    it "uses only username when common_name is blank" do
      payload["common_name"] = ""
      expect(parser.parse[:device_name]).to eq("rtulino")
    end

    it "uses only common_name when username is absent" do
      payload.delete("username")
      expect(parser.parse[:device_name]).to eq("ryans-macbook")
    end

    it "uses only common_name when username is blank" do
      payload["username"] = ""
      expect(parser.parse[:device_name]).to eq("ryans-macbook")
    end

    it "uses username alone when username and common_name are equal" do
      payload["common_name"] = "rtulino"
      expect(parser.parse[:device_name]).to eq("rtulino")
    end

    it 'falls back to "Unknown VPN user" when both username and common_name are absent' do
      payload.delete("username")
      payload.delete("common_name")
      expect(parser.parse[:device_name]).to eq("Unknown VPN user")
    end

    it 'falls back to "Unknown VPN user" when both are blank' do
      payload["username"]    = ""
      payload["common_name"] = ""
      expect(parser.parse[:device_name]).to eq("Unknown VPN user")
    end
  end

  # ------------------------------------------------------------------ #
  # device_id resolution (source_ip)                                    #
  # ------------------------------------------------------------------ #
  describe "#parse device_id" do
    it "uses source_ip as the device_id" do
      expect(parser.parse[:device_id]).to eq("203.0.113.42")
    end

    it 'falls back to "unknown" when source_ip is absent' do
      payload.delete("source_ip")
      expect(parser.parse[:device_id]).to eq("unknown")
    end

    it 'falls back to "unknown" when source_ip is blank' do
      payload["source_ip"] = ""
      expect(parser.parse[:device_id]).to eq("unknown")
    end
  end

  # ------------------------------------------------------------------ #
  # occurred_at resolution (timestamp_unix)                             #
  # ------------------------------------------------------------------ #
  describe "#parse occurred_at" do
    it "parses a valid unix timestamp string into a Time" do
      result = parser.parse[:occurred_at]
      expect(result).to be_a(Time)
      expect(result.to_i).to eq(1_756_310_400)
    end

    it "falls back to Time.current when timestamp_unix is missing" do
      payload.delete("timestamp_unix")
      freeze_time = Time.zone.now
      allow(Time).to receive(:current).and_return(freeze_time)
      expect(parser.parse[:occurred_at]).to eq(freeze_time)
    end

    it "falls back to Time.current when timestamp_unix is nil" do
      payload["timestamp_unix"] = nil
      freeze_time = Time.zone.now
      allow(Time).to receive(:current).and_return(freeze_time)
      expect(parser.parse[:occurred_at]).to eq(freeze_time)
    end

    it "falls back to Time.current when timestamp_unix is blank" do
      payload["timestamp_unix"] = ""
      freeze_time = Time.zone.now
      allow(Time).to receive(:current).and_return(freeze_time)
      expect(parser.parse[:occurred_at]).to eq(freeze_time)
    end

    it "falls back to Time.current when timestamp_unix is non-numeric" do
      payload["timestamp_unix"] = "not-a-number"
      freeze_time = Time.zone.now
      allow(Time).to receive(:current).and_return(freeze_time)
      expect(parser.parse[:occurred_at]).to eq(freeze_time)
    end
  end

  # ------------------------------------------------------------------ #
  # Full parse result shape                                              #
  # ------------------------------------------------------------------ #
  describe "#parse return value" do
    it "returns a hash with the expected keys" do
      result = parser.parse
      expect(result.keys).to match_array(%i[event_type device_name device_id occurred_at])
    end
  end
end
