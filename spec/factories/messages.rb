FactoryBot.define do
  factory :message do
    association :chat
    role { "user" }
    content { "Test message content" }

    trait :user_message do
      role { "user" }
    end

    trait :assistant_message do
      role { "assistant" }
    end
  end
end
