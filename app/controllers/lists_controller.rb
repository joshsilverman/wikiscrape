class ListsController < ApplicationController




  # GET /lists
  # GET /lists.xml
  def index
    @lists = List.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @lists }
    end
  end

  # GET /lists/1
  # GET /lists/1.xml
  def show
    @list = List.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @list }
    end
  end

  # GET /lists/new
  # GET /lists/new.xml
  def new

    @list = List.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @list }
    end
  end

  # GET /lists/1/edit
  def edit
    @list = List.find(params[:id])
  end

  # POST /lists
  # POST /lists.xml
  def create

    @term_names = params[:list][:csv].split /(?:\n|\r)+/
    @questions = []

    @term_names.each_with_index do |term, i|
      @errors = []
      @questions << {:term => term}

      term = term.gsub(/^\s+|\s+$/, "").gsub(" ", "_")

      @topic = slow_lookup(term)
      if @topic
        @questions[i][:question] = to_question(@topic)      
        @questions[i][:answers] = false_answers @topic, @questions[i][:question]
        @questions[i][:topic] = @topic
        @questions[i][:errors] = @errors
      end
    end

    @list = List.new(params[:list])

    render :action => "show"
    
#    respond_to do |format|
#      if @list.save
#        format.html { redirect_to(@list, :notice => 'List was successfully created.') }
#        format.xml  { render :xml => @list, :status => :created, :location => @list }
#      else
#        format.html { render :action => "new" }
#        format.xml  { render :xml => @list.errors, :status => :unprocessable_entity }
#      end
#    end
  end

  def update
    @list = List.find(params[:id])

    respond_to do |format|
      if @list.update_attributes(params[:list])
        format.html { redirect_to(@list, :notice => 'List was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @list.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /lists/1
  # DELETE /lists/1.xml
  def destroy
    @list = List.find(params[:id])
    @list.destroy

    respond_to do |format|
      format.html { redirect_to(lists_url) }
      format.xml  { head :ok }
    end
  end

  private

  def slow_lookup name
    human_name = name.gsub("_", " ")
    @term = Term.find_by_term(human_name)
    @topic = Topic.find_by_id(@term.topic_id) if @term
    puts "Lookup Started"
    # fetch and save if no topic
    if @term.nil? or @topic.nil?
      puts "Term not found"
      #look for a wiki article that hits
      get_wiki_article_name(name)

      @topic = Topic.find_by_name(@n)
      if @topic.nil? or @topic.description.nil?
        topic_details = lookup(@good_name)

        return if topic_details.nil?

        disambig = topic_details[:all] =~ /This disambiguation page lists articles associated with the same title./i
        unless disambig.nil?
          return
        end

        if @topic.nil?
          temp= topic_details[:description][0].to_s
          topic_details[:description][0] = temp.gsub("—", "-").split('').find_all {|c| (0x00..0x7f).include? c.ord }.join('')
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

              begin
                cats_topics.each do |topic_name|
                  topic = Topic.find_by_name(topic_name)
                  unless topic
                    t = @cat.topics.create(:name => topic_name)
                    Term.create(:term => topic_name, :topic_id => t.id)
                  end
                end
              rescue
                @errors << "rescue no topics for this category"
              end
            end
          end
          begin
            @cat.topics << @topic
          rescue
            @errors << "rescue slow_lookup can't add topic to cat"
          end
        end
      end
    else

      if @topic.description.nil?
        topic_details = lookup(name)

        return if topic_details.nil?

        @topic.update_attributes(
          :img_url => (topic_details[:image][0] if topic_details[:image]),
          :description => (topic_details[:description][0] if topic_details[:description]))

        topic_details[:catlinks].each do |cat_name|

        @cat = Cat.find_by_name(cat_name)
          Cat.transaction do
            if not @cat
              cats_topics = cat_lookup(cat_name)

              @cat = Cat.create!(:name => cat_name)

              begin
                cats_topics.each do |topic_name|
                  topic = Topic.find_by_name(topic_name)
                    @cat.topics.create(:name => topic_name) unless topic
                end
              rescue
                @errors << "no cat topics to speak of..."
              end
            end
          end
        end
      end

    end

    return @topic
  end

#  def multiple_choice
#    @fill_in_blank = ""
#    @choices = []
#
#    human_name = params[:name].gsub("_", " ")
#    @term = Term.find_by_term(human_name)
#    if @term
#      @topic = Topic.find_by_id(@term.topic_id)
#      if @topic.description
#        @fill_in_blank = to_question(@topic)
#        @choices = answers(@topic, @fill_in_blank)
#      end
#    end
#  end

  def false_answers(topic, blanked)

    # Linguistics::use( :en )
    # tgr = EngTagger.new
    # text = "Alice chased the big fat cat."

    # # Add part-of-speech tags to text
    # tagged = tgr.add_tags(text)
    # puts tagged
    
    # puts Linguistics::EN.has_wordnet?

    #build buckets
    @topics = Topic.find_by_id(topic.id, :include => [{:cats => :topics}])
    desc_words = blanked.gsub(/\(|\)|\?|\.|\[|\]/, '').split(' ')

    # Remove parenthesis

    # Check POS

    # Check number

    # Check 

    # Check Wordnet


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
    choices = Set.new([topic.name])
    cat_buckets.each do |bucket|
      bucket[:cat].topics.each do |topic|
        puts topic.name
      end
      bucket[:cat].topics.limit(3).all.each do |rel_topic|
        choices.add rel_topic.name
        break if choices.length == 10
      end
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

  def to_question(topic)

    get_text = Scraper.define do
      process "p", :just_text => :text
      result :just_text
    end

    text = "Error"
    begin
      raw_text = get_text.scrape(topic.description)
      raw_text.gsub! /\<[^>]*>\]/, ""
      raw_text.gsub! /\[[^]*]\]/, ""
      raw_text.gsub! /\([^)]*\)/, ""
      first_sent = raw_text.split(/\.\s*"?[A-Z]|\.$/)[0]
      chunks = first_sent.split(/ (is|are|was|were|refers to|comprises) /)

      if chunks[1] == "refers to"
        question_word = "What "
      else
        question_word = "Which "
      end

      text = (question_word + chunks[1..(chunks.length - 1)].join(" ")).gsub(/^\s+|\s+$/, '') + "?"
    rescue
      @errors << "to_question failed to scrape topic description. Description: #{raw_text}"
    end

    return text
  end

  def get_wiki_article_name(name)
    found = false
      name_stack = create_name_stack(name)
      until found
        begin
          found = true
          unless name_stack.empty?
            @good_name = name_stack.pop
            @n = quick_lookup(@good_name)
          end
        rescue
          found = false
          @errors << "rescue slow_lookup:quick_lookup failure"
        end
      end
  end

  def quick_lookup(n)
    qwiki = Scraper.define do
      process "#firstHeading", :name => :text
      result  :name
    end
    article = qwiki.scrape(URI.parse("http://en.wikipedia.org/wiki/#{n}"))
    puts "CHECK ARTICLE"
    return article
  end

  def create_name_stack(n)
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

  def lookup(name)
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
      process "body", :all => :text
#      process "a", :catlinks => :text
      result  :name, :image, :follow, :catlinks, :all, :description
    end

   begin
    puts "http://en.wikipedia.org/wiki/#{name}"
    
    article = wiki_article.scrape(URI.parse("http://en.wikipedia.org/wiki/#{name}"))
    article.description = article.description[description_index..-1]

   rescue
     @errors << "rescue lookup can't lookup term"
     return
   end

    # follow "may refer to:"
    if article.description and article.description.size > 0 and (article.description[description_index] =~ /may refer to:$/)
      if article.follow.length > 1
        article = wiki_article.scrape(URI.parse("http://en.wikipedia.org#{article.follow[0]}"))
      end
    end
    return article
  end

  def cat_lookup(name)

    wiki_cat = Scraper.define do
      array :names
      process "#mw-pages li >a", :names => :text
      result  :names
    end

    wiki_cat.options[:user_agent] = "Mozilla/4.0"
    begin
      topic_names = wiki_cat.scrape(URI.parse("http://en.wikipedia.org/wiki/Category:#{name.gsub(" ", "_")}"))
    rescue
      @errors << "rescue cat_lookup:topic_names"
    end
    puts "CATEGORY IS " + name.to_s
    topic_names.each do |t|
      puts t
    end
    return topic_names
  end

end
