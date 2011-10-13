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

ActiveRecord::Schema.define(:version => 20111012201620) do

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

  create_table "delayed_jobs", :force => true do |t|
    t.integer  "priority",   :default => 0
    t.integer  "attempts",   :default => 0
    t.text     "handler"
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "delayed_jobs", ["priority", "run_at"], :name => "delayed_jobs_priority"

  create_table "documents", :force => true do |t|
    t.text     "csv"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "name"
  end

  create_table "documents_topic_identifiers", :id => false, :force => true do |t|
    t.integer "document_id"
    t.integer "topic_identifier_id"
  end

  create_table "topic_identifiers", :force => true do |t|
    t.string   "name"
    t.integer  "topic_id"
    t.boolean  "is_disambiguation"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "topic_search_terms", :force => true do |t|
    t.string   "name"
    t.integer  "topic_id"
    t.boolean  "is_disambiguation"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "topics", :force => true do |t|
    t.string   "name"
    t.text     "img_url"
    t.text     "description"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
