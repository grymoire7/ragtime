FactoryBot.define do
  factory :model do
    sequence(:model_id) { |n| "test-model-#{n}" }
    name { "Test Model" }
    provider { "ollama" }
    family { "test-family" }
    context_window { 8192 }
    capabilities { ["chat"] }

    trait :gemma3 do
      model_id { "gemma3:latest" }
      name { "Gemma 3 (Ollama)" }
      provider { "ollama" }
      family { "gemma3" }
    end

    trait :jina_embeddings do
      model_id { "jina/jina-embeddings-v2-small-en" }
      name { "Jina Embeddings v2 Small (Ollama)" }
      provider { "ollama" }
      family { "jina-bert-v2" }
      capabilities { ["embedding"] }
    end
  end
end
