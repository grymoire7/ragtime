class AddErrorMessageToDocuments < ActiveRecord::Migration[8.0]
  def change
    add_column :documents, :error_message, :text
  end
end
