# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Seeding models..."

# Production models (OpenAI)
production_models = [
  {
    model_id: 'gpt-4o-mini',
    name: 'GPT-4o Mini (OpenAI)',
    provider: :openai,
    family: 'gpt-4',
    context_window: 128000,
    capabilities: ['chat', 'function_calling']
  },
  {
    model_id: 'text-embedding-3-small',
    name: 'Text Embedding 3 Small (OpenAI)',
    provider: :openai,
    family: 'text-embedding-3',
    context_window: 8191,
    capabilities: ['embedding']
  }
]

# Development models (Anthropic + Ollama)
development_models = [
  {
    model_id: 'claude-3-5-haiku-20241022',
    name: 'Claude 3.5 Haiku (Anthropic)',
    provider: :anthropic,
    family: 'claude-3-5',
    context_window: 200000,
    capabilities: ['chat']
  },
  {
    model_id: 'jina/jina-embeddings-v2-small-en',
    name: 'Jina Embeddings v2 Small (Ollama)',
    provider: :ollama,
    family: 'jina-bert-v2',
    context_window: 8192,
    capabilities: ['embedding']
  }
]

# Test models
test_models = [
  {
    model_id: 'test-chat-model',
    name: 'Test Chat Model',
    provider: :test,
    family: 'test',
    context_window: 4096,
    capabilities: ['chat']
  },
  {
    model_id: 'test-embedding-model',
    name: 'Test Embedding Model',
    provider: :test,
    family: 'test',
    context_window: 8192,
    capabilities: ['embedding']
  }
]

# Combine all models
all_models = production_models + development_models + test_models

created_count = 0
updated_count = 0

all_models.each do |attrs|
  model = Model.find_or_initialize_by(model_id: attrs[:model_id])

  if model.new_record?
    model.assign_attributes(attrs)
    model.save!
    created_count += 1
    puts "  + Created: #{attrs[:name]} (#{attrs[:model_id]})"
  else
    # Update existing model attributes
    model.update!(attrs.except(:model_id))
    updated_count += 1
    puts "  ✓ Updated: #{attrs[:name]} (#{attrs[:model_id]})"
  end
end

puts "\nSeed complete!"
puts "  Created: #{created_count} models"
puts "  Updated: #{updated_count} models"
puts "  Total: #{Model.count} models in database"
