FactoryBot.define do
  factory :notification_preference do
    association      :user
    doorbell_pressed { true }
    motion_detected  { true }

    trait :all_disabled do
      doorbell_pressed { false }
      motion_detected  { false }
    end

    trait :doorbell_only do
      doorbell_pressed { true }
      motion_detected  { false }
    end

    trait :motion_only do
      doorbell_pressed { false }
      motion_detected  { true }
    end
  end
end
