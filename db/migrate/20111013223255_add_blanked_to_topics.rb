class AddBlankedToTopics < ActiveRecord::Migration
  def self.up
  	add_column :topics, :blanked, :text
  end

  def self.down
  	remove_column :topics, :blanked
  end
end
