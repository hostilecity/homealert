class User < ApplicationRecord
  validates :google_uid, presence: true, uniqueness: true
  validates :email, presence: true, uniqueness: true
  validates :name, presence: true

  def self.from_omniauth(auth)
    find_or_initialize_by(google_uid: auth.uid).tap do |user|
      user.email      = auth.info.email
      user.name       = auth.info.name
      user.avatar_url = auth.info.image
      user.save!
    end
  end
end
