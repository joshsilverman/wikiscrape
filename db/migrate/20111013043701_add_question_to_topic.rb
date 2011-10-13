class AddQuestionToTopic < ActiveRecord::Migration
  def self.up
    add_column :topics, :question, :text
  end

  def self.down
    remove_column :topics, :question
  end
end
