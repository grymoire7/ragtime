namespace :models do
  desc "Sync Ollama models to the database"
  task sync_ollama: :environment do
    puts "Syncing Ollama models to database..."

    ollama_models = [
      {
        model_id: 'gemma3:latest',
        name: 'Gemma 3 (Ollama)',
        provider: :ollama,
        family: 'gemma3',
        context_window: 8192
      },
      {
        model_id: 'jina/jina-embeddings-v2-small-en',
        name: 'Jina Embeddings v2 Small (Ollama)',
        provider: :ollama,
        family: 'jina-bert-v2',
        context_window: 8192,
        capabilities: ['embedding']
      },
      {
        model_id: 'mistral-small:latest',
        name: 'Mistral Small (Ollama)',
        provider: :ollama,
        family: 'mistral',
        context_window: 32768
      },
      {
        model_id: 'llama3.2:3b',
        name: 'Llama 3.2 3B (Ollama)',
        provider: :ollama,
        family: 'llama',
        context_window: 128000
      },
      {
        model_id: 'llama3.2:1b',
        name: 'Llama 3.2 1B (Ollama)',
        provider: :ollama,
        family: 'llama',
        context_window: 128000
      }
    ]

    created_count = 0
    updated_count = 0

    ollama_models.each do |attrs|
      model = Model.find_by(model_id: attrs[:model_id])

      if model
        # Update existing model
        model.update!(attrs.except(:model_id))
        updated_count += 1
        puts "  ✓ Updated: #{attrs[:name]} (#{attrs[:model_id]})"
      else
        # Create new model
        model = Model.create!(attrs)
        created_count += 1
        puts "  + Created: #{attrs[:name]} (#{attrs[:model_id]})"
      end
    end

    puts "\nSync complete!"
    puts "  Created: #{created_count} models"
    puts "  Updated: #{updated_count} models"
  end

  desc "List all Ollama models in the database"
  task list_ollama: :environment do
    ollama_models = Model.where(provider: :ollama).order(:name)

    if ollama_models.empty?
      puts "No Ollama models found in database."
      puts "Run 'rails models:sync_ollama' to add them."
    else
      puts "Ollama models in database:"
      puts "-" * 80
      ollama_models.each do |model|
        puts "  #{model.name.ljust(40)} | #{model.model_id}"
      end
      puts "-" * 80
      puts "Total: #{ollama_models.count} models"
    end
  end

  desc "Remove all Ollama models from the database"
  task clean_ollama: :environment do
    count = Model.where(provider: :ollama).count

    if count.zero?
      puts "No Ollama models to remove."
    else
      print "Are you sure you want to remove #{count} Ollama models? (y/N): "
      response = STDIN.gets.chomp.downcase

      if response == 'y'
        Model.where(provider: :ollama).destroy_all
        puts "Removed #{count} Ollama models."
      else
        puts "Cancelled."
      end
    end
  end
end
