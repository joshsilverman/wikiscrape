class Topic < ActiveRecord::Base
  
  has_and_belongs_to_many :cats, :uniq => true
  has_many :topic_identifiers
  has_many :answers

  def self.wiki_page_name(name)
    name_stack = create_name_stack(name.gsub(" ","_"))
    article_name = nil
    while article_name.nil? and not name_stack.empty?
      temp_name = name_stack.pop
      puts temp_name
      article_name = quick_lookup(temp_name)
    end
    return article_name
  end

  def self.lookup_on_wiki(name)
    article = scrape_body(name) 
    return {:article => article, :follow => article.follow}
  end

  def self.wiki_disambiguate(name, term_id)   
    article = scrape_body(name)
    topic_identifier = TopicIdentifier.find_by_id(term_id)
    topic = Topic.create(
        :name => (article[:name] if article[:name]),
        :img_url => (article[:image][0] if article[:image]),
        :description => (Document.clean_markup_from_desc(article[:description][0]) if article[:description]),
        :blanked => article[:description][0]      
    )
    Answer.delete_all(:topic_id => term_id)
    topic_identifier.update_attributes({:topic_id => topic.id, :is_disambiguation => false})
    Cat.add_categories(article[:catlinks])
    
    #Problem: categories are being added, but asynchronously, none are found in build QA
    # topic.build_q_and_a
  end

  def self.scrape_body(name)
    name.gsub!(" ","_")
    name.gsub!("/wiki/", "")
    description_index = nil
    wiki_article = Scraper.define do
      array :description
      array :image
      array :follow
      array :catlinks

      i = 0
      process "#bodyContent p", :description=>:element do |element|
        description_index = i if ((element.to_s =~ /^<p[^>]*>[a-zA-Z]|^<p[^>]*><b/) == 0 or (element.to_s =~ /^<p[^>]*>[a-zA-Z]|^<p[^>]*><i><b/) == 0) and not description_index
        i += 1
      end
      process "#firstHeading", :name => :text
      process ".infobox img, .thumb img", :image => "@src"
      process "#bodyContent ul >li >a", :follow => "@href"
      process "#mw-normal-catlinks >ul >li >a", :catlinks => :text
      process "body", :all_html => :text
      process "#disambig_placeholder", :disambig => :text
#      process "a", :catlinks => :text
      result  :name, :image, :follow, :catlinks, :all_html, :description, :disambig
    end

    begin
      article = nil
      puts "scraping http://en.wikipedia.org/wiki/#{name}"
      article = wiki_article.scrape(URI.parse("http://en.wikipedia.org/wiki/#{name}"))
      article.description = article.description[description_index..-1]
      article.disambig = false
      disambig = article.all_html =~ /This disambiguation page lists articles associated with the same title./i
      article.disambig = true unless disambig.nil?
      article.all_html = nil 
      return article
    rescue
      puts "Error scraping!"
      return nil
    end
  end

  def build_q_and_a
    question = ""
    question = self.to_question if self.question.nil?
    if question.length > 10
      self.update_attribute(:question, question)
      answers = self.false_answers
      puts "Answers:"
      puts answers.to_json
      if answers.size > 1
        answers.each do |answer|
          Answer.find_or_create_by_name_and_topic_id(answer, self.id)
        end
      end
    end
  end

  # private

  def to_question
    raw_text = self.description
    text = "Error"
    begin
      first_sent = raw_text.split(/\.\s*"?[A-Z]|\.$/)[0]
      chunks = first_sent.split(/ (is|are|was|were|refers to|comprises) /)

      if chunks[1] == "refers to"
        question_word = "What "
      else
        question_word = "Which "
      end
      text = (question_word + chunks[1..(chunks.length - 1)].join(" ")).gsub(/^\s+|\s+$/, '') + "?"
    rescue
      puts "Error occured in to_question"
      return
    end

    return text
  end

  def false_answers
    choices = Set.new() #[self.name]
    # begin
      @topics = Topic.find_by_id(self.id, :include => [{:cats => :topics}])
      puts @topics.to_json
      puts @topics.cats.to_json
      desc_words = self.question.gsub(/\(|\)|\?|\.|\[|\]/, '').split(' ')

      cat_buckets = []
      @topics.cats.each {|cat| cat_buckets.push({:cat => cat, :rel => 0})}
      self.name.split(' ').each {|n| desc_words.push(n)}

      # For each word in the question, check if it is in the category title text, if so, augment its relevance score
      desc_words.each do |desc_word|
        cat_buckets.each do |bucket|
          bucket[:rel] += 1 if bucket[:cat].name =~ /#{desc_word}/i and desc_word.length > 3
        end
      end

      # Check to make sure its not an identical match, then normalize bucket relevance by dividing by the number of words
      cat_buckets.each do |bucket|
        words = bucket[:cat].name.split(' ')
        if bucket[:cat].name =~ /#{self.name}/i
          bucket[:rel] = 0.0
        else
          bucket[:rel] = bucket[:rel] / words.size.to_f
        end
      end

      # Eliminate irrelevant buckets, sort by relevance
      # cat_buckets = cat_buckets.find_all{|bucket| bucket[:rel] >= 0.2}
      cat_buckets = cat_buckets.find_all{|bucket| not bucket[:cat].name =~ /^Articles with/}
      cat_buckets = cat_buckets.sort_by{|bucket| 1/bucket[:rel]}
      cat_buckets.each {|bucket| puts bucket[:cat].name + ": " + bucket[:rel].to_s}

      # Iterate through the buckets, picking three terms from each, until the maximum of ten terms has been reached
      cat_buckets.each do |bucket|
        scored_topics = []
        puts "Checking category #{bucket[:cat].name}"  
        bucket[:cat].topics.each do |top|
          # Remove parenthesis
          top.name = top.name.gsub /\([^)]*\)/, ""
          next if self.name.strip == top.name.strip
          @votes = 0
          # Check if word ending and beginning the same
          @votes += 1 if self.matching_word_endings(top.name)
          @votes += 1 if self.matching_word_beginnings(top.name)
          # Check if same number of words
          @votes += 1 if self.name.split(" ").length == top.name.split(" ").length
          scored_topics.push({:topic => top.name.gsub(/\([^)]*\)/, ""), :votes => @votes})     
        end
        scored_topics.sort! {|a,b| a[:votes] <=> b[:votes] }

        for i in (0..2) do
          next if choices.length >= 10
          choices.add scored_topics.pop[:topic]
        end    
        
        # bucket[:cat].topics.each do |topic|
        #   puts topic.name
        # end
        # bucket[:cat].topics.limit(3).all.each do |rel_topic|
        #   puts rel_topic.name
        #   choices.add rel_topic.name
        #   break if choices.length == 10
        # end
      end

      scored_topics.sort! {|a,b| a[:votes] <=> b[:votes] }

      for i in (0..2) do
        next if choices.length >= 10
        choices.add scored_topics.pop[:topic] unless scored_topics.empty?
      end    
      
      return choices.to_a
    # rescue
    #   puts "Error generating false answers!"
    #   return choices.to_a
    # end
  end

  def matching_word_endings(compare)
    return true if self.name.strip[-3, 3] == compare.strip[-3, 3]
    return false
  end

  def matching_word_beginnings(compare)
    return true if self.name.strip[0..2] == compare.strip[1..2]
    return false
  end

  def self.quick_lookup(n)
    puts n
    agent = Mechanize.new { |agent| agent.user_agent_alias = 'Mac Safari'}
    agent.follow_meta_refresh = true

    begin
      @redirect = nil
      page = agent.get("http://en.wikipedia.org/w/index.php?title=#{n}&redirect=no")
      page.search(".redirectText").each do |item|
        @redirect = item.at("a")[:href]
      end
    rescue
      puts "redirect check rescued"
      @redirect = nil
    end

    @redirect = "/wiki/#{n}" if @redirect.nil?

    qwiki = Scraper.define do
      process "#firstHeading", :name => :text
      result  :name
    end
    
    begin
      article = qwiki.scrape(URI.parse("http://en.wikipedia.org#{@redirect}"))
      return article
    rescue
      return nil
    end
  end

  def self.create_name_stack(n)
    puts n
    name_stack = []

    name_stack.push(n.gsub(" ", "_"))
    n.gsub!(/\([^)]*\)/, "_")

    #add all caps but articles
    temp = n.split(/_|\s/)
    for i in (0..(temp.size-1)) do
      w = temp[i]
      unless w=="is" || w=="and" || w=="the" || w=="of"
        temp[i] = temp[i].capitalize
      end
    end
    word = temp.join("_")
    name_stack.push(word)
    name_stack.push(word.capitalize)
    name_stack.push(n)
    return name_stack
  end

end
