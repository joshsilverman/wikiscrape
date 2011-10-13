class Topic < ActiveRecord::Base
  
  has_and_belongs_to_many :cats, :uniq => true
  has_many :topic_identifiers
  has_many :answers

  def self.wiki_page_name(name)
    puts "WIKI PAGE NAME"
    name_stack = create_name_stack(name.gsub(" ","_"))
    article_name = nil
    while article_name.nil? and not name_stack.empty?
      temp_name = name_stack.pop
      article_name = quick_lookup(temp_name)
      puts "article"
      puts article_name
    end
    return article_name
  end

  def self.lookup_on_wiki(name)
    puts "lookup on wiki"
    name.gsub!(" ","_")
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
    rescue
      puts "Error scraping!"
      return nil
    end
    puts article.description[0]
    puts article.name
    puts article.image[0] if article.image
    disambig = article.all_html =~ /This disambiguation page lists articles associated with the same title./i
    article.disambig = true unless disambig.nil?
    article.all_html = nil
    puts article.disambig
    
    return article
  end

  def build_q_and_a
    puts "BUIling..."
    question = ""
    question = Topic.to_question(self) if self.question.nil?
    if question.length > 10
      self.update_attribute(:question, question)
      answers = Topic.false_answers(self, question)
      if answers.size>1
        answers.each do |answer|
          Answer.find_or_create_by_name_and_topic_id(answer, self.id)
        end
      end
    end
  end

  private
  def self.to_question(topic)

    raw_text = topic.description

    # get_text = Scraper.define do
    #   process "p", :just_text => :text
    #   result :just_text
    # end

    text = "Error"
    begin
      # raw_text = get_text.scrape(topic.description)
      # raw_text.gsub! /\<[^>]*>\]/, ""
      # raw_text.gsub! /\[[^]*]\]/, ""
      # raw_text.gsub! /\([^)]*\)/, ""
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

  def self.false_answers(topic, blanked)
    @topics = Topic.find_by_id(topic.id, :include => [{:cats => :topics}])
    desc_words = blanked.gsub(/\(|\)|\?|\.|\[|\]/, '').split(' ')

    cat_buckets = []
    @topics.cats.each {|cat| cat_buckets.push({:cat => cat, :rel => 0})}
    topic.name.split(' ').each {|n| desc_words.push(n)}

    # For each word in the question, check if it is in the category title text, if so, augment its relevance score
    desc_words.each do |desc_word|
      cat_buckets.each do |bucket|
        bucket[:rel] += 1 if bucket[:cat].name =~ /#{desc_word}/i and desc_word.length > 3
      end
    end

    # Check to make sure its not an identical match, then normalize bucket relevance by dividing by the number of words
    cat_buckets.each do |bucket|
      words = bucket[:cat].name.split(' ')
      if bucket[:cat].name =~ /#{topic.name}/i
        bucket[:rel] = 0.0
      else
        bucket[:rel] = bucket[:rel] / words.size.to_f
      end
    end

    # Eliminate irrelevant buckets, sort by relevance
    cat_buckets = cat_buckets.find_all{|bucket| bucket[:rel] >= 0.2}
    cat_buckets = cat_buckets.find_all{|bucket| not bucket[:cat].name =~ /^Articles with/}
    cat_buckets = cat_buckets.sort_by{|bucket| 1/bucket[:rel]}
    cat_buckets.each {|bucket| puts bucket[:cat].name + ": " + bucket[:rel].to_s}

    # Iterate through the buckets, picking three terms from each, until the maximum of ten terms has been reached
    choices = Set.new() #[topic.name]
    cat_buckets.each do |bucket|
      scored_topics = []
      puts "Checking category #{bucket[:cat].name}"  
      bucket[:cat].topics.each do |top|
        # Remove parenthesis
        top.name = top.name.gsub /\([^)]*\)/, ""
        next if topic.name.strip == top.name.strip
        @votes = 0
        # Check if word ending and beginning the same
        @votes += 1 if matching_word_endings?(topic.name, top.name) 
        @votes += 1 if matching_word_beginnings?(topic.name, top.name)
        # Check if same number of words
        @votes += 1 if topic.name.split(" ").length == top.name.split(" ").length
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

    puts "GENERATING FALSE ANSWERS:\n"
    puts "Question: #{blanked}"
    puts "Topic: #{topic.name}"
    puts "Wrong answers: "
    choices.to_a.each do |choice|
      puts "  - #{choice}"
    end
    puts "\n\n"

    return choices.to_a
  end

  def self.matching_word_endings?(base, compare)
    return true if base.strip[-3, 3] == compare.strip[-3, 3]
    return false
  end

  def self.matching_word_beginnings?(base, compare)
    return true if base.strip[0..2] == compare.strip[1..2]
    return false
  end

  def self.quick_lookup(n)
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
      puts "http://en.wikipedia.org#{@redirect}"
      article = qwiki.scrape(URI.parse("http://en.wikipedia.org#{@redirect}"))
      return article
    rescue
      return nil
    end
  end

  def self.create_name_stack(n)
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
