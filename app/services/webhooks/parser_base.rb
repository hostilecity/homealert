module Webhooks
  # Base interface for device-specific webhook parsers.
  # Subclasses must implement #parse and return an attributes hash
  # suitable for Event.create! or raise Webhooks::UnknownEventError.
  class ParserBase
    def initialize(payload)
      @payload = payload
    end

    def parse
      raise NotImplementedError, "#{self.class}#parse is not implemented"
    end

    private

    attr_reader :payload
  end

  UnknownEventError = Class.new(StandardError)
end
