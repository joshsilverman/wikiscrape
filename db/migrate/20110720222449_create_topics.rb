class CreateTopics < ActiveRecord::Migration
  def self.up
    create_table :topics do |t|
      t.string :name
      t.string :img_url
      t.string :description

      t.timestamps
    end
  end

  def self.down
    drop_table :topics
  end
end
