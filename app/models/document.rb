class Document < ActiveRecord::Base
  has_and_belongs_to_many :topic_identifiers

  def self.ambiguous_terms
    puts "yeah son"
  end

  def self.parse_list(id)
    @document = Document.find_by_id(id)
    @topic_identifiers = @document.csv.split /(?:\n|\r)+/
    @ambiguous_terms = []
    @topic_identifiers.each do |ti|
      puts "START LOOP"
      puts ti
      #check if the topic_identifier exists already
      @topic_identifier = TopicIdentifier.find_by_name(ti)

      if @topic_identifier.nil?
        #check topic_identifier for wiki article
        topic_name = Topic.wiki_page_name(ti)
        puts "Topic name: #{topic_name}"

        #if article doesnt exist return
        if topic_name.nil?
          @document.topic_identifiers << TopicIdentifier.create(:name => ti)
          next

        #else article exists
        else
          @topic = Topic.find_by_name(topic_name)
          #check for topic
          if @topic && @topic.description
            @document.topic_identifiers << TopicIdentifier.create(:name => ti, :topic_id => @topic.id)
          elsif @topic
            #look up article on wikipedia
            full_topic = Topic.lookup_on_wiki(topic_name)
            #if it's a disambig page create identifier and throw disambig flag
            if full_topic[:disambig]
              @document.topic_identifiers << TopicIdentifier.create(:name => ti, :is_disambiguation => true)
              @ambiguous_terms << {:name => ti, :id => ti, :links => full_topic[:follow]}
            else
              #otherwise update the topic with new info and create identifier for it
              @topic.update_attributes(
                  :img_url => (full_topic[:image][0] if full_topic[:image]),
                  :description => (Document.clean_markup_from_desc(full_topic[:description][0]) if full_topic[:description]),
                  :blanked => full_topic[:description][0])
              @document.topic_identifiers << TopicIdentifier.create(:name => ti, :topic_id => @topic.id)
              Cat.add_categories(full_topic[:catlinks])
              @topic.build_q_and_a
            end
          else
            #create topic from wiki
            full_topic = Topic.lookup_on_wiki(topic_name)[:article]
            #if it's a disambig page create identifier and throw disambig flag
            if full_topic[:disambig]
              @document.topic_identifiers << TopicIdentifier.create(:name => ti, :is_disambiguation => true)
              @ambiguous_terms << {:name => ti, :id => ti, :links => full_topic[:follow]}
            else
              #otherwise update the topic with new info and create identifier for it
              @topic = Topic.create(
                  :name => (full_topic[:name] if full_topic[:name]),
                  :img_url => (full_topic[:image][0] if full_topic[:image]),
                  :description => (Document.clean_markup_from_desc(full_topic[:description][0]) if full_topic[:description]),
                  :blanked => full_topic[:description][0])
              @document.topic_identifiers << TopicIdentifier.create(:name => ti, :topic_id => @topic.id)
              Cat.add_categories(full_topic[:catlinks])
              @topic.build_q_and_a
            end
          end
        end
      else
        @document.topic_identifiers << @topic_identifier
        next if @topic_identifier.topic_id.nil?  
        @topic = Topic.find_by_id(@topic_identifier.topic_id)
        #check if linked topic has full desc
        if @topic.description.nil?
          full_topic = Topic.lookup_on_wiki(@topic.name)
          ## HANDLE THIS EVENT
          puts "Topic:"
          next if full_topic.nil?
          
          #if it's a disambig page create identifier and throw disambig flag
          if full_topic[:disambig]
            @topic_identifier.update_attribute(:is_disambiguation, true)
            @ambiguous_terms << {:name => ti, :id => ti, :links => full_topic[:follow]}
            next
          else
            #otherwise update the topic with new info and create identifier for it
            @topic.update_attributes(
                :img_url => (full_topic[:article][:image][0] if full_topic[:article][:image]),
                :description => (Document.clean_markup_from_desc(full_topic[:article][:description][0]) if full_topic[:article][:description]),
                :blanked => full_topic[:article][:description][0])
            Cat.add_categories(full_topic[:article][:catlinks])
            @topic.build_q_and_a
          end
        end
      end
    end
    return @ambiguous_terms
  end

  def self.clean_markup_from_desc(str)
    get_text = Scraper.define do
      process "p", :just_text => :text
      result :just_text
    end

    begin
      raw_text = get_text.scrape(str)
      raw_text.gsub! /\<[^>]*>\]/, ""
      raw_text.gsub! /\[[^]*]\]/, ""
      raw_text.gsub! /\([^)]*\)/, ""
      raw_text.gsub!(" ,", ",")
    rescue
      raw_text =  "ERROR!!"
    end

    return raw_text
  end 
  
end
