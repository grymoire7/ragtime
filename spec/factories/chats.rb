FactoryBot.define do
  factory :chat do
    association :model, factory: [:model, :gemma3]
  end
end
