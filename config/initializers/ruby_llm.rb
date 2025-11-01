RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY'] || Rails.application.credentials.dig(:openai_api_key)
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY'] || Rails.application.credentials.dig(:anthropic_api_key)
  config.ollama_api_base = 'http://localhost:11434/v1'
  
  config.default_model = 'claude-3-5-haiku-latest'
  config.default_embedding_model = "voyage-3.5-lite"
  
  # Use the new association-based acts_as API (recommended)
  config.use_new_acts_as = true
end

Rails.application.configure do
  config.x.ruby_llm = {
    development: {
      chat: {
        model: 'gemma3:latest',
        provider: :ollama
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
        model: 'claude-3-5-haiku-latest',
        provider: :anthropic
      },
      embedding: {
        model: 'voyage-3.5-lite',
        provider: :anthropic
      }
    }
  }
end
