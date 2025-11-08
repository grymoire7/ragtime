RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY'] || Rails.application.credentials.dig(:openai_api_key)
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY'] || Rails.application.credentials.dig(:anthropic_api_key)
  config.ollama_api_base = 'http://localhost:11434/v1'

  config.default_model = 'claude-3-5-haiku-20241022'
  config.default_embedding_model = "voyage-3.5-lite"
  
  # Use acts_as API but don't load models from database (use JSON registry instead)
  config.use_new_acts_as = true
  config.model_registry_class = nil  # Forces fallback to JSON model registry
end

Rails.application.configure do
  config.x.ruby_llm = {
    development: {
      chat: {
        model: 'claude-3-5-haiku-20241022',
        provider: :anthropic
      },
      embedding: {
        model: 'jina/jina-embeddings-v2-small-en',
        provider: :ollama
      }
    },
    test: {
      chat: {
        model: 'test-chat-model',
        provider: :test
      },
      embedding: {
        model: 'test-embedding-model',
        provider: :test
      }
    },
    production: {
      chat: {
        model: 'gpt-4o-mini',
        provider: :openai
      },
      embedding: {
        model: 'text-embedding-3-small',
        provider: :openai
      }
    }
  }
end
