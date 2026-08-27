FactoryBot.define do
  factory :notification_preference do
    association      :user
    doorbell_pressed { true }
    motion_detected  { true }
    vpn_login        { false }

    trait :all_disabled do
      doorbell_pressed { false }
      motion_detected  { false }
      vpn_login        { false }
    end

    trait :doorbell_only do
      doorbell_pressed { true }
      motion_detected  { false }
      vpn_login        { false }
    end

    trait :motion_only do
      doorbell_pressed { false }
      motion_detected  { true }
      vpn_login        { false }
    end

    trait :vpn_login_only do
      doorbell_pressed { false }
      motion_detected  { false }
      vpn_login        { true }
    end
  end
end
