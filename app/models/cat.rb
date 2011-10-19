class Cat < ActiveRecord::Base

  has_and_belongs_to_many :topics, :uniq => true

  def self.cat_lookup(name)

    wiki_cat = Scraper.define do
      array :names
      process "#mw-pages li >a", :names => :text
      result  :names
    end

    wiki_cat.options[:user_agent] = "Mozilla/4.0"
    begin
      topic_names = wiki_cat.scrape(URI.parse("http://en.wikipedia.org/wiki/Category:#{name.gsub(" ", "_")}"))
    rescue
      puts "Error in cat_lookup"
    end

    return topic_names
  end

  def self.add_categories(cat_names)
    cat_names.each do |cat_name|
      @cat = Cat.find_by_name(cat_name)
      Cat.transaction do
        if not @cat
          cats_topic_names = cat_lookup(cat_name)
          @cat = Cat.create!(:name => cat_name)
          return if cats_topic_names.nil?
          cats_topic_names.each do |topic_name|
            begin
              topic_identifier = TopicIdentifier.find_or_create_by_name(topic_name)
              topic = Topic.find_by_name(topic_identifier.name)
              if topic
                topic_identifier.update_attribute(:topic_id, topic.id)
                @cat.topics << topic
              else
                topic = Topic.create(:name => topic_name)
                topic_identifier.update_attribute(:topic_id, topic.id)
                @cat.topics << topic
              end
            rescue
              puts "Found illegal characters in category #{topic_name}... skipping."
            end
          end
        end
      end
    end
  end

end
