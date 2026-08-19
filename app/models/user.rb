class User < ApplicationRecord
  validates :google_uid, presence: true, uniqueness: true
  validates :email, presence: true, uniqueness: true
  validates :name, presence: true

  def self.allowlist
    ENV.fetch("ALLOWED_EMAILS", "").split(",").map(&:strip).map(&:downcase).reject(&:empty?)
  end

  def self.allowed?(email)
    allowlist.include?(email.to_s.downcase)
  end

  def self.from_omniauth(auth)
    email = auth.info.email.to_s.downcase

    raise NotAllowedError, "#{email} is not on the allowlist" unless allowed?(email)

    find_or_initialize_by(google_uid: auth.uid).tap do |user|
      user.email      = email
      user.name       = auth.info.name
      user.avatar_url = auth.info.image
      user.save!
    end
  end

  class NotAllowedError < StandardError; end
end
