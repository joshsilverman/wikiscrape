class CreateDocumentsTopicIdentifiersTable < ActiveRecord::Migration
  def self.up
    create_table :documents_topic_identifiers, :id => false do |t|
        t.references :document
        t.references :topic_identifier
    end
  end

  def self.down
    drop_table :documents_topic_identifiers
  end
end
