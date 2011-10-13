class Document < ActiveRecord::Base
  has_and_belongs_to_many :topic_identifiers

  def self.parse_list(id)
    @document = Document.find_by_id(id)
    @topic_identifiers = @document.csv.split /(?:\n|\r)+/
    @topic_identifiers.each do |ti|
      puts "START LOOP"
      puts ti

      #check if the topic_identifier exists already
      @topic_identifier = TopicIdentifier.find_by_name(ti)

      if @topic_identifier.nil?
        puts "topic identifier nil"
        #check topic_identifier for wiki article
        topic_name = Topic.wiki_page_name(ti)
        puts "topic_name:"
        puts topic_name

        #if article doesnt exist return
        if topic_name.nil?
          @document.topic_identifiers << TopicIdentifier.create(:name => ti)
          next

        #else article exists
        else
          puts "article exists"
          @topic = Topic.find_by_name(topic_name)
          #check for topic
          if @topic && @topic.description
            puts "full topic found"
            puts @topic.inspect
            @document.topic_identifiers << TopicIdentifier.create(:name => ti, :topic_id => @topic.id)
          elsif @topic
            puts "unfinished topic found"
            puts @topic.inspect
            #look up article on wikipedia
            full_topic = Topic.lookup_on_wiki(topic_name)
            puts full_topic[:disambig]
            #if it's a disambig page create identifier and throw disambig flag
            if full_topic[:disambig]
              @document.topic_identifiers << TopicIdentifier.create(:name => ti, :is_disambiguation => true)
            else
              puts "update topic with new info"
              #otherwise update the topic with new info and create identifier for it
              @topic.update_attributes(
                  :img_url => (full_topic[:image][0] if full_topic[:image]),
                  :description => (full_topic[:description][0] if full_topic[:description]))
              puts "create / add topic identifier to doc"
              @document.topic_identifiers << TopicIdentifier.create(:name => ti, :topic_id => @topic.id)
              puts "KITTIES?"
              Cat.add_categories(full_topic[:catlinks])
              puts "No...just cats"
              Topic.build_q_and_a(@topic)
            end
          else
            #create topic from wiki
            puts "create topic from scratch"
            full_topic = Topic.lookup_on_wiki(topic_name)
            puts full_topic[:disambig]
            #if it's a disambig page create identifier and throw disambig flag
            if full_topic[:disambig]
              @document.topic_identifiers << TopicIdentifier.create(:name => ti, :is_disambiguation => true)
            else
              puts "creating new topic"
              #otherwise update the topic with new info and create identifier for it
              @topic = Topic.create(
                  :name => (full_topic[:name] if full_topic[:name]),
                  :img_url => (full_topic[:image][0] if full_topic[:image]),
                  :description => (full_topic[:description][0] if full_topic[:description]))
              puts "now creeating/saving topic identifier"
              @document.topic_identifiers << TopicIdentifier.create(:name => ti, :topic_id => @topic.id)
              puts "CATS!"
              Cat.add_categories(full_topic[:catlinks])
              puts "Cats done"
              Topic.build_q_and_a(@topic)
            end
          end
        end
      else
        @document.topic_identifiers << @topic_identifier
        @topic = Topic.find_by_id(@topic_identifier.topic_id)
        #check if linked topic has full desc
        if @topic.description.nil?
          full_topic = Topic.lookup_on_wiki(@topic.name)

          #if it's a disambig page create identifier and throw disambig flag
          if full_topic[:disambig]
            next
          else
            #otherwise update the topic with new info and create identifier for it
            @topic.update_attributes(
                :img_url => (full_topic[:image][0] if full_topic[:image]),
                :description => (full_topic[:description][0] if full_topic[:description]))
            Cat.add_categories(full_topic[:catlinks])
            Topic.build_q_and_a(@topic)
          end
        end
      end
    end
  end
  
end
