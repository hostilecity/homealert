FactoryBot.define do
  factory :push_subscription do
    association :user
    sequence(:endpoint) { |n| "https://fcm.googleapis.com/fcm/send/subscription_#{n}" }
    p256dh_key   { Faker::Crypto.sha256 }
    auth_key     { Faker::Crypto.md5 }
    device_label { "Test Device" }
  end
end
