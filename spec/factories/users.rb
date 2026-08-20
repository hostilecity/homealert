FactoryBot.define do
  factory :user do
    sequence(:google_uid) { |n| "google_uid_#{n}" }
    sequence(:email)      { |n| Faker::Internet.unique.email(name: "user#{n}") }
    name                  { Faker::Name.name }
    avatar_url            { Faker::Internet.url(host: "lh3.googleusercontent.com") }
  end
end
