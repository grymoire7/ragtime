class CreateDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :documents do |t|
      t.string :title
      t.string :filename
      t.string :content_type
      t.integer :file_size
      t.string :status
      t.datetime :processed_at

      t.timestamps
    end

    add_index :documents, :status
    add_index :documents, :created_at
  end
end
