class CreateChunks < ActiveRecord::Migration[8.0]
  def change
    create_table :chunks do |t|
      t.references :document, null: false, foreign_key: true
      t.text :content
      t.integer :position
      t.integer :token_count
      t.binary :embedding  # Store vector embedding as BLOB

      t.timestamps
    end

    add_index :chunks, :position

    # Create virtual table for vector similarity search using sqlite-vec
    # voyage-3-lite produces 512-dimensional embeddings
    reversible do |dir|
      dir.up do
        execute <<-SQL
          CREATE VIRTUAL TABLE vec_chunks USING vec0(
            chunk_id INTEGER PRIMARY KEY,
            embedding FLOAT[512]
          );
        SQL
      end
      dir.down do
        execute "DROP TABLE IF EXISTS vec_chunks;"
      end
    end
  end
end
