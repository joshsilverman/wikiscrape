class CreateCatsTopicsJoinTable < ActiveRecord::Migration

  def self.up
    create_table :cats_topics, :id => false do |t|
      t.references :cat, :null => false
      t.references :topic, :null => false
    end

    add_index(:cats_topics, [:cat_id, :topic_id], :unique => true)
  end

  def self.down
    drop_table :cats_topics
  end

end