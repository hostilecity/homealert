module Webhooks
  class ReoLinkController < ApplicationController
    skip_before_action :require_authentication
    skip_before_action :verify_authenticity_token

    def create
      attributes = Webhooks::ReoLinkParser.new(payload).parse
      event = Event.create!(attributes)
      PushNotificationJob.perform_later(event.id)
      head :ok
    rescue Webhooks::UnknownEventError => e
      Rails.logger.warn("ReoLink webhook ignored: #{e.message}")
      head :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("ReoLink webhook failed to persist: #{e.message}")
      head :unprocessable_entity
    end

    private

    def payload
      unless request.content_type&.include?("application/json")
        raise Webhooks::UnknownEventError, "Unsupported content type: #{request.content_type.inspect}"
      end

      JSON.parse(request.body.read)
    rescue JSON::ParserError => e
      raise Webhooks::UnknownEventError, "Invalid JSON payload: #{e.message}"
    end
  end
end
