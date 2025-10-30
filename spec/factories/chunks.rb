FactoryBot.define do
  factory :chunk do
    association :document
    content { "This is a sample chunk of text from a document. It contains enough content to be meaningful for testing purposes." }
    sequence(:position) { |n| n }
    token_count { 20 }

    trait :with_embedding do
      after(:build) do |chunk|
        # Create a dummy 512-dimensional embedding
        chunk.embedding = Array.new(512) { rand }
      end
    end

    trait :large do
      content { "This is a much larger chunk of text. " * 50 }
      token_count { 200 }
    end
  end
end
