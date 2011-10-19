class TopicsController < ApplicationController

  def index
    @topics = Topic.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @topics }
    end
  end

  def update
    @topic = Topic.find_by_id(params[:id])
    @topic.answers.delete_all
    @topic.update_attributes(:name => params[:topic][:name], 
      :description => params[:topic][:description],
      :question => params[:topic][:question])
    params[:answers][:text].split("\n").each do |answer|
      @topic.answers.create(:topic_id => params[:id], :name => answer.strip)
    end
    render :nothing => true
  end

  def get_topic
    ## INCLUDES QUESTION + ANSWERS!!
    @ti = TopicIdentifier.find_by_id(params[:term_id])
    @topic = @ti.topic
    @answers = Answer.all(:conditions => {:topic_id => @ti.id})
    render :json => {"topic" => @topic, "answers" => @answers}
  end

  def test
    description_index = nil
    wiki_article = Scraper.define do
      array :description
      array :image
      array :follow
      array :catlinks

      i = 0
      process "#bodyContent >p", :description=>:element do |element|
        description_index = i if (element.to_s =~ /^<p[^>]*>[a-zA-Z]|^<p[^>]*><b/) == 0 and not description_index
        i += 1
      end
      process "#firstHeading", :name => :text
      process ".infobox img, .thumb img", :image => "@src"
      process "#bodyContent>ul>li>a", :follow => "@href"
      process "#catlinks span a", :catlinks => :text
#      process "a", :catlinks => :text

      result  :name, :image, :description, :follow, :catlinks
    end
    
    get_text = Scraper.define do
      process "p", :just_text => :text
      result :just_text
    end
    
    name = params[:name]

    puts name
    
    article = wiki_article.scrape(URI.parse("http://en.wikipedia.org/wiki/#{name}"))

    article.description = article.description[description_index..-1]
    # follow "may refer to:"
    if article.description and article.description.size > 0 and (article.description[description_index] =~ /may refer to:$/)
      if article.follow.length > 1
        article = wiki_article.scrape(URI.parse("http://en.wikipedia.org#{article.follow[0]}"))
      end
    end

    nobold = article.description[0].to_s.gsub(/<b>/, "</b>").split("</b>").map(&:strip).reject(&:empty?)
    puts nobold
    i = 0
    temp = []
    nobold.each do |b|
      if i%2 == 0
        temp[i]=b
      else
        temp[i]="________"
      end
      i+=1
    end

    @temp1 = temp.join(' ')
    beg = @temp1 =~ /\(/
    tend = @temp1 =~ /\)/
    p1 = @temp1[0..(beg-1)]
    p2 = @temp1[(tend+1)..-1]

    @html = p1+p2

    @html = @html.gsub(/\[.*\]/, "")

    @fill_in_blank = get_text.scrape(@html)
  end

  def get
    human_name = params[:name].gsub("_", " ")
    @term = Term.find_by_term(human_name)
    # fetch and save if no topic
    if @term.nil?
      found = false
      name_stack = create_name_stack(params[:name])
      until found
        begin
          found = true
          unless name_stack.empty?
            @good_name = name_stack.pop
            @n = quick_lookup(@good_name)
          end
          puts @n
        rescue
          found = false
          puts "rescue"
        end
      end

      @topic = Topic.find_by_name(@n)
      if @topic.nil? or @topic.description.nil?
        topic_details = lookup(@good_name)
        disambig = topic_details[:all] =~ /This disambiguation page lists articles associated with the same title./i
        unless disambig.nil?
          return
        end

        

        if @topic.nil?
          temp= topic_details[:description][0].to_s
          topic_details[:description][0] = temp.split('').find_all {|c| (0x00..0x7f).include? c.ord }.join('')
          @topic = Topic.create(
            :name => (topic_details[:name] if topic_details[:name]),
            :img_url => (topic_details[:image][0] if topic_details[:image]),
            :description => (topic_details[:description][0] if topic_details[:description]))
          Term.create(:term => human_name, :topic_id => @topic.id)
        end

        topic_details[:catlinks].each do |cat_name|

          @cat = Cat.find_by_name(cat_name)
          Cat.transaction do
            if not @cat
              cats_topics = cat_lookup(cat_name)

              @cat = Cat.create!(:name => cat_name)
              cats_topics.each do |topic_name|
                topic = Topic.find_by_name(topic_name)
                unless topic
                  t = @cat.topics.create(:name => topic_name)
                  Term.create(:term => topic_name, :topic_id => t.id)
                end
              end
            end
          end
          @cat.topics << @topic
        end
      end
      else
        @topic = Topic.find_by_id(@term.topic_id)

        if @topic.description.nil?
          topic_details = lookup(params[:name])

          @topic.update_attributes(
            :img_url => (topic_details[:image][0] if topic_details[:image]),
            :description => (topic_details[:description][0] if topic_details[:description]))

          topic_details[:catlinks].each do |cat_name|

          @cat = Cat.find_by_name(cat_name)
            Cat.transaction do
              if not @cat
                cats_topics = cat_lookup(cat_name)

                @cat = Cat.create!(:name => cat_name)
                cats_topics.each do |topic_name|
                  topic = Topic.find_by_name(topic_name)
                    @cat.topics.create(:name => topic_name) unless topic
                end
              end
            end
          end
        end
      end
      get_text = Scraper.define do
        process "p", :just_text => :text
        result :just_text
      end
      @topic.description = get_text.scrape(@topic.description)

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @topic }
      format.json  { render :json => @topic.as_json(:only => [:description, :img_url]) }
    end
  end

  def multiple_choice
    @fill_in_blank = ""
    @choices = []

    human_name = params[:name].gsub("_", " ")
    @term = Term.find_by_term(human_name)
    if @term
      @topic = Topic.find_by_id(@term.topic_id)
      if @topic.description
        @fill_in_blank = to_question(@topic)
        @choices = answers(@topic, @fill_in_blank)
      end
    end

    @mc_json = {:blank => @fill_in_blank, :answers => {:c_answer => @choices[0], :i_answer => @choices[1..3]}}
    @mc_json = @mc_json.to_json

    respond_to do |format|
      format.html # index.html.erb
      format.json  { render :json => @mc_json }
    end
  end

  def destroy
    @topic = Topic.find(params[:id])
    @topic.destroy

    respond_to do |format|
      format.html { redirect_to(lists_url) }
      format.xml  { head :ok }
    end
  end

  private

  def answers(topic, blanked)

    #build buckets
    @topics = Topic.find_by_id(topic.id, :include => [{:cats => :topics}])
    desc_words = blanked.gsub(/\(|\)|\?|\.|\[|\]/,'').split(' ')
    cat_buckets = []
    @topics.cats.each {|cat| cat_buckets.push({:cat => cat, :rel => 0})}
    topic.name.split(' ').each {|n| desc_words.push(n)}

    desc_words.each do |desc_word|
      cat_buckets.each do |bucket|
        bucket[:rel] += 1 if bucket[:cat].name =~ /#{desc_word}/i and desc_word.length > 3
      end
    end

    # rate bucket relevance
    cat_buckets.each do |bucket|
      words = bucket[:cat].name.split(' ')
      if bucket[:cat].name =~ /#{topic.name}/i
        bucket[:rel] = 0.0
      else
        bucket[:rel] = bucket[:rel] / words.size.to_f
      end
    end

    # filter order and draw from buckets
    cat_buckets = cat_buckets.find_all{|bucket| bucket[:rel] >= 0.2}
    cat_buckets = cat_buckets.find_all{|bucket| not bucket[:cat].name =~ /^Articles with/}
    cat_buckets = cat_buckets.sort_by{|bucket| 1/bucket[:rel]}
    cat_buckets.each {|bucket| puts bucket[:cat].name + ": " + bucket[:rel].to_s}

    choices = Set.new([topic.name])
    cat_buckets.each do |bucket|
      scored_topics = []
      puts "Checking category #{bucket[:cat].name}"  
      bucket[:cat].topics.each do |top|
        top.name = top.name.gsub /\([^)]*\)/, ""
        next if topic.name.strip == top.name.strip
        @votes = 0
        @votes += 1 if matching_word_endings?(topic.name, top.name) 
        @votes += 1 if matching_word_beginnings?(topic.name, top.name)
        @votes += 1 if topic.name.split(" ").length == top.name.split(" ").length
        scored_topics.push({:topic => top.name.gsub(/\([^)]*\)/, ""), :votes => @votes})     
      end
      scored_topics.sort! {|a,b| a[:votes] <=> b[:votes] }

      for i in (0..2) do
        next if choices.length >= 10
        choices.add scored_topics.pop[:topic]
      end
      # bucket[:cat].topics.limit(3).all.each do |rel_topic|
      #   choices.add rel_topic.name
      #   break if choices.length == 10
      # end
    end

    return choices.to_a
  end

  def matching_word_endings?(base, compare)
    return true if base.strip[-3, 3] == compare.strip[-3, 3]
    return false
  end

  def matching_word_beginnings?(base, compare)
    return true if base.strip[0..2] == compare.strip[1..2]
    return false
  end

  def to_question(topic)

    get_text = Scraper.define do
      process "p", :just_text => :text
      result :just_text
    end

    text = "Error"
    begin
      raw_text = get_text.scrape(topic.description)
      raw_text.gsub! /\[[^]*]\]/, ""
      first_sent = raw_text.split(/\.\s*[A-Z]|\.$/)[0]
      chunks = first_sent.split(/ (is|are|was|were|refers to|comprises) /)

      if chunks[1] == "refers to"
        question_word = "What "
      else
        question_word = "Which "
      end
      text = question_word + chunks[1..(chunks.length - 1)].join(" ") + "?"

    rescue
    end

    return text
  end

  def fill_in_blank(topic)

    get_text = Scraper.define do
      process "p", :just_text => :text
      result :just_text
    end

    nobold = topic.description.to_s.gsub(/<b>/, "</b>").split("</b>").reject(&:empty?)
    i = 0
    temp = []
    nobold.each do |b|
      if i%2 == 0
        temp[i]=b
      else
        temp[i]="________"
      end
      i+=1
    end

    html = temp.join(' ')
    text = get_text.scrape(html)
    beg = text.index('(')
    tend = text.index(')')
    unless beg.nil? or tend.nil?
      p1 = text[0..(beg-1)]
      p2 = text[(tend+1)..-1]
      text = p1+p2
    end

    text = text.gsub(/#{topic.name}/i, '________').gsub(/\[[0-9]\]/, "").gsub(/\[citation needed\]/i, "")
    return text
  end

  def create_name_stack(n)
    name_stack = []
    #add all caps but articles
    temp = n.split("_")
    for i in (0..(temp.size-1)) do
      w = temp[i]
      unless w=="is" || w=="and" || w=="the" || w=="of"
        temp[i] = temp[i].capitalize
        puts temp[i]
      end
    end
    word = temp.join("_")
    puts word
    puts word.capitalize
    puts n
    name_stack.push(word)
    name_stack.push(word.capitalize)
    name_stack.push(n)
    puts name_stack
    return name_stack
  end

  def quick_lookup(n)
    qwiki = Scraper.define do
      process "#firstHeading", :name => :text
      result  :name
    end
    article = qwiki.scrape(URI.parse("http://en.wikipedia.org/wiki/#{n}"))
    return article
  end

  def lookup(name)
    description_index = nil
    wiki_article = Scraper.define do
      array :description
      array :image
      array :follow
      array :catlinks

      i = 0
      process "#bodyContent >p", :description=>:element do |element|
        description_index = i if ((element.to_s =~ /^<p[^>]*>[a-zA-Z]|^<p[^>]*><b/) == 0 or (element.to_s =~ /^<p[^>]*>[a-zA-Z]|^<p[^>]*><i><b/) == 0) and not description_index
        i += 1
      end
      process "#firstHeading", :name => :text
      process ".infobox img, .thumb img", :image => "@src"
      process "#bodyContent>ul>li>a", :follow => "@href"
      process "#catlinks span a", :catlinks => :text
      process "body", :all => :text
#      process "a", :catlinks => :text

      result  :name, :image, :description, :follow, :catlinks, :all
    end
    puts "Lookup on " + name
    puts URI.parse("http://en.wikipedia.org/wiki/#{name}")
    article = wiki_article.scrape(URI.parse("http://en.wikipedia.org/wiki/#{name}"))
    article.description = article.description[description_index..-1]

    # follow "may refer to:"
    if article.description and article.description.size > 0 and (article.description[description_index] =~ /may refer to:$/)
      if article.follow.length > 1
        article = wiki_article.scrape(URI.parse("http://en.wikipedia.org#{article.follow[0]}"))
      end
    end
    return article
  end

  def legal_lookup
  end

  def med_lookup
  end

  def bio_lookup
  end

  def cat_lookup(name)

    puts name

    wiki_cat = Scraper.define do
      array :names
      process "#mw-pages li a", :names => :text
      result  :names
    end

    wiki_cat.options[:user_agent] = "Mozilla/4.0"
    topic_names = wiki_cat.scrape(URI.parse("http://en.wikipedia.org/wiki/Category:#{name.gsub(" ", "_")}"))
    return topic_names
  end
end
