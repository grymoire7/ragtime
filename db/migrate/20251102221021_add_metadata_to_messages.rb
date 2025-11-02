class AddMetadataToMessages < ActiveRecord::Migration[8.0]
  def change
    add_column :messages, :metadata, :json, default: {}
  end
end
