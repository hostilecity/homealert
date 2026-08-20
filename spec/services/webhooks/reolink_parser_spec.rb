require "rails_helper"

RSpec.describe Webhooks::ReoLinkParser do
  subject(:parser) { described_class.new(payload) }

  let(:base_alarm) do
    {
      "type"        => "visitor",
      "deviceModel" => "RLC-810A",
      "channelName" => "Front Door",
      "device"      => "device-001",
      "alarmTime"   => "2026-08-20 10:00:00"
    }
  end

  let(:payload) { { "alarm" => base_alarm } }

  # ------------------------------------------------------------------ #
  # event_type resolution                                                #
  # ------------------------------------------------------------------ #
  describe "#parse event_type" do
    it 'maps "visitor" to "doorbell_pressed"' do
      expect(parser.parse[:event_type]).to eq("doorbell_pressed")
    end

    it 'maps "people" to "motion_detected"' do
      payload["alarm"]["type"] = "people"
      expect(parser.parse[:event_type]).to eq("motion_detected")
    end

    it 'maps "VISITOR" (uppercase) to "doorbell_pressed" (case-insensitive)' do
      payload["alarm"]["type"] = "VISITOR"
      expect(parser.parse[:event_type]).to eq("doorbell_pressed")
    end

    it 'maps "PEOPLE" (uppercase) to "motion_detected"' do
      payload["alarm"]["type"] = "PEOPLE"
      expect(parser.parse[:event_type]).to eq("motion_detected")
    end

    it "raises UnknownEventError for an unrecognised type" do
      payload["alarm"]["type"] = "some_unknown_event"
      expect { parser.parse }.to raise_error(Webhooks::UnknownEventError, /Unrecognised ReoLink type/)
    end

    it "raises UnknownEventError when type is nil" do
      payload["alarm"]["type"] = nil
      expect { parser.parse }.to raise_error(Webhooks::UnknownEventError)
    end
  end

  # ------------------------------------------------------------------ #
  # Missing alarm key                                                    #
  # ------------------------------------------------------------------ #
  describe "#parse with missing alarm key" do
    let(:payload) { { "data" => "irrelevant" } }

    it "raises UnknownEventError" do
      expect { parser.parse }.to raise_error(Webhooks::UnknownEventError, /Missing 'alarm' key/)
    end
  end

  # ------------------------------------------------------------------ #
  # device_name resolution                                               #
  # ------------------------------------------------------------------ #
  describe "#parse device_name" do
    it "combines deviceModel and channelName" do
      expect(parser.parse[:device_name]).to eq("RLC-810A — Front Door")
    end

    it "uses only deviceModel when channelName is absent" do
      payload["alarm"].delete("channelName")
      expect(parser.parse[:device_name]).to eq("RLC-810A")
    end

    it "uses only deviceModel when channelName is blank" do
      payload["alarm"]["channelName"] = ""
      expect(parser.parse[:device_name]).to eq("RLC-810A")
    end

    it 'falls back to "ReoLink Device" when deviceModel is absent' do
      payload["alarm"].delete("deviceModel")
      payload["alarm"].delete("channelName")
      expect(parser.parse[:device_name]).to eq("ReoLink Device")
    end

    it 'falls back to "ReoLink Device" when deviceModel is blank' do
      payload["alarm"]["deviceModel"] = ""
      payload["alarm"].delete("channelName")
      expect(parser.parse[:device_name]).to eq("ReoLink Device")
    end

    it 'combines "ReoLink Device" with channelName when only channelName is present' do
      payload["alarm"]["deviceModel"] = ""
      payload["alarm"]["channelName"] = "Side Gate"
      expect(parser.parse[:device_name]).to eq("ReoLink Device — Side Gate")
    end
  end

  # ------------------------------------------------------------------ #
  # device_id resolution                                                 #
  # ------------------------------------------------------------------ #
  describe "#parse device_id" do
    it "uses the device field when present" do
      expect(parser.parse[:device_id]).to eq("device-001")
    end

    it "falls back to channel.to_s when device is absent" do
      payload["alarm"].delete("device")
      payload["alarm"]["channel"] = 42
      expect(parser.parse[:device_id]).to eq("42")
    end

    it 'falls back to "unknown" when both device and channel are absent' do
      payload["alarm"].delete("device")
      payload["alarm"].delete("channel")
      expect(parser.parse[:device_id]).to eq("unknown")
    end

    it 'falls back to "unknown" when device is blank' do
      payload["alarm"]["device"] = ""
      payload["alarm"].delete("channel")
      expect(parser.parse[:device_id]).to eq("unknown")
    end
  end

  # ------------------------------------------------------------------ #
  # occurred_at resolution                                               #
  # ------------------------------------------------------------------ #
  describe "#parse occurred_at" do
    it "parses a valid alarmTime string" do
      result = parser.parse[:occurred_at]
      expect(result).to be_a(Time)
      expect(result.year).to eq(2026)
      expect(result.month).to eq(8)
      expect(result.day).to eq(20)
    end

    it "falls back to Time.current when alarmTime is missing" do
      payload["alarm"].delete("alarmTime")
      freeze_time = Time.zone.now
      allow(Time).to receive(:current).and_return(freeze_time)
      expect(parser.parse[:occurred_at]).to eq(freeze_time)
    end

    it "falls back to Time.current when alarmTime is nil" do
      payload["alarm"]["alarmTime"] = nil
      freeze_time = Time.zone.now
      allow(Time).to receive(:current).and_return(freeze_time)
      expect(parser.parse[:occurred_at]).to eq(freeze_time)
    end

    it "falls back to Time.current when alarmTime is out of range (raises ArgumentError)" do
      # Time.zone.parse returns nil for plain nonsense strings but raises
      # ArgumentError for out-of-range values like month 13.
      payload["alarm"]["alarmTime"] = "2024-13-01 00:00:00"
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
