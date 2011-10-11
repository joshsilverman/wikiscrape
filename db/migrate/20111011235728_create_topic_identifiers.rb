class CreateTopicIdentifiers < ActiveRecord::Migration
  def self.up
    create_table :topic_identifiers do |t|
      t.string :name
      t.integer :topic_id
      t.boolean :is_disambiguation

      t.timestamps
    end
  end

  def self.down
    drop_table :topic_identifiers
  end
end
