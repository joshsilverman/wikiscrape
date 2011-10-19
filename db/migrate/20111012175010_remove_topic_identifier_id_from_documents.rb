class RemoveTopicIdentifierIdFromDocuments < ActiveRecord::Migration
  def self.up
    remove_column :documents, :topic_identifier_id
    add_column :documents, :name, :string
  end

  def self.down
     add_column :documents, :topic_identifier_id, :int
     remove_column :documents, :name
  end
end
