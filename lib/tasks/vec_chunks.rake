# frozen_string_literal: true

namespace :vec_chunks do
  desc "Initialize vec_chunks virtual table (drops and recreates)"
  task init: :environment do
    puts "🔧 Initializing vec_chunks virtual table..."
    puts ""
    puts "🗑️  Dropping all vec_chunks related tables..."

    # List of all possible shadow tables created by sqlite-vec
    shadow_tables = [
      "vec_chunks",
      "vec_chunks_info",
      "vec_chunks_data",
      "vec_chunks_config",
      "vec_chunks_chunks",
      "vec_chunks_rowids",
      "vec_chunks_vector_chunks00"
    ]

    # Drop each table if it exists
    shadow_tables.each do |table|
      begin
        ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS #{table}")
        puts "   Dropped: #{table}"
      rescue => e
        # Table might not exist, that's ok
      end
    end

    puts ""
    puts "📦 Creating fresh vec_chunks virtual table..."

    # Create the virtual table with 1536 dimensions (OpenAI embeddings)
    ActiveRecord::Base.connection.execute(<<~SQL)
      CREATE VIRTUAL TABLE vec_chunks USING vec0(
        chunk_id INTEGER PRIMARY KEY,
        embedding FLOAT[1536]
      );
    SQL

    puts "✅ vec_chunks table created successfully"
    puts ""

    # Verify
    count = ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM vec_chunks").first.values.first
    puts "📊 Current vec_chunks rows: #{count}"
  end
end
