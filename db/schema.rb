# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20110721183959) do

  create_table "cats", :force => true do |t|
    t.string   "name"
    t.string   "url"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "cats_topics", :id => false, :force => true do |t|
    t.integer "cat_id",   :null => false
    t.integer "topic_id", :null => false
  end

  add_index "cats_topics", ["cat_id", "topic_id"], :name => "index_cats_topics_on_cat_id_and_topic_id", :unique => true

  create_table "links", :force => true do |t|
    t.integer  "topic_id"
    t.integer  "ref_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "references", :id => false, :force => true do |t|
    t.integer "ref_id",   :null => false
    t.integer "topic_id", :null => false
  end

  add_index "references", ["ref_id", "topic_id"], :name => "index_references_on_ref_id_and_topic_id", :unique => true

  create_table "topics", :force => true do |t|
    t.string   "name"
    t.string   "url"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
