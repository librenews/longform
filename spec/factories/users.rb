FactoryBot.define do
  factory :user do
    sequence(:handle) { |n| "user#{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    display_name { Faker::Name.name }
    avatar_url { Faker::Avatar.image }
    
    # OAuth data that would come from Bluesky
    provider { "atproto" }
    uid { "did:plc:#{SecureRandom.alphanumeric(22)}" }
    access_token { SecureRandom.hex(32) }
    refresh_token { SecureRandom.hex(32) }
    
    # Timestamps
    created_at { 1.month.ago }
    updated_at { 1.week.ago }

    trait :with_posts do
      after(:create) do |user|
        create_list(:post, 3, user: user)
      end
    end

    trait :with_published_posts do
      after(:create) do |user|
        create_list(:post, 2, :published, user: user)
        create_list(:post, 1, :draft, user: user)
      end
    end

    trait :fresh_tokens do
      token_expires_at { 1.hour.from_now }
    end

    trait :expired_tokens do
      token_expires_at { 1.hour.ago }
    end
  end
end
