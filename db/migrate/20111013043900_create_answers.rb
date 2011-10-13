class CreateAnswers < ActiveRecord::Migration
  def self.up
    create_table :answers do |t|
      t.integer :topic_id
      t.string :name

      t.timestamps
    end
  end

  def self.down
    drop_table :answers
  end
end
