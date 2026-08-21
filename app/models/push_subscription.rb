class PushSubscription < ApplicationRecord
  belongs_to :user

  validates :endpoint,   presence: true, uniqueness: true
  validates :p256dh_key, presence: true
  validates :auth_key,   presence: true

  def web_push_keys
    { p256dh: p256dh_key, auth: auth_key }
  end

  # A push endpoint is a bearer capability, so it is never rendered into the
  # page. The digest is enough for the browser to recognise which of the
  # listed devices is the one it is currently running on.
  def endpoint_digest
    Digest::SHA256.hexdigest(endpoint.to_s)
  end
end
