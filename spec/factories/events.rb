FactoryBot.define do
  factory :event do
    event_type  { "doorbell_pressed" }
    device_name { Faker::Device.model_name }
    sequence(:device_id) { |n| "device_#{n}" }
    occurred_at { Time.current }

    trait :doorbell_pressed do
      event_type { "doorbell_pressed" }
    end

    trait :motion_detected do
      event_type { "motion_detected" }
    end
  end
end
