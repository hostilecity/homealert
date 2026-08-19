module Webhooks
  class ReoLinkController < ApplicationController
    skip_before_action :require_authentication
    skip_before_action :verify_authenticity_token

    def create
      attributes = Webhooks::ReoLinkParser.new(payload).parse
      Event.create!(attributes)
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
      # Accept both JSON body and form-encoded params
      if request.content_type&.include?("application/json")
        JSON.parse(request.body.read)
      else
        params.to_unsafe_h.except("controller", "action")
      end
    end
  end
end
