class Document < ActiveRecord::Base
  has_and_belongs_to_many :topic_identifiers

  def self.parse_list(id)
    @document = Document.find_by_id(id)
    @topic_identifiers = @document.csv.split /(?:\n|\r)+/
    @topic_identifiers.each do |ti|

      #check if the topic_identifier exists already
      @topic_identifier = TopicIdentifier.find_by_name(ti)

      if @topic_identifier.nil?
        #check topic_identifier for wiki article
        topic_name = Topic.wiki_page_name(ti)

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
            else

              #otherwise update the topic with new info and create identifier for it
              @topic.update_attributes(
                  :img_url => (full_topic[:image][0] if full_topic[:image]),
                  :description => (full_topic[:description][0] if full_topic[:description]))

              @document.topic_identifiers << TopicIdentifier.create(:name => ti, :topic_id => @topic.id)
              Cat.add_categories(full_topic[:catlinks])
            end
          else
            #create topic from wiki
            full_topic = Topic.lookup_on_wiki(topic_name)

            #if it's a disambig page create identifier and throw disambig flag
            if full_topic[:disambig]
              @document.topic_identifiers << TopicIdentifier.create(:name => ti, :is_disambiguation => true)
            else

              #otherwise update the topic with new info and create identifier for it
              @topic = Topic.create(
                  :name => (full_topic[:name] if full_topic[:name]),
                  :img_url => (full_topic[:image][0] if full_topic[:image]),
                  :description => (full_topic[:description][0] if full_topic[:description]))

              @document.topic_identifiers << TopicIdentifier.create(:name => ti, :topic_id => @topic.id)
              Cat.add_categories(full_topic[:catlinks])
            end
          end
        end
      else
        @document.topic_identifiers << @topic_identifier
      end
    end
  end

end
