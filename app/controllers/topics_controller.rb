class TopicsController < ApplicationController

  def index
    @topics = Topic.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @topics }
    end
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
      puts 'TERM NIL'
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
        @fill_in_blank = fill_in_blank(@topic)
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

  private

  def answers(topic, blanked)
    @wrong = []
    @topics = Topic.find_by_id(topic.id, :include => [{:cats => :topics}])
    desc_words = blanked.split(' ')
    cat_buckets = []
    @topics.cats.each do |c|
      cat_buckets.push([0, c.name, c.id])
    end
    topic.name.split(' ').each do |n|
      desc_words.push(n)
    end

    desc_words.each do |w|
      cat_buckets.each do |b|
        if b[1] =~ /#{w.gsub('(','').gsub(')','')}/i && w.length > 3
          b[0]+=1
        end
      end
    end
    puts desc_words.inspect
    puts cat_buckets.inspect
    
    max_score = 0
    cat_buckets.each do |b|
      words = b[1].split(' ')
      if b[1] =~ /#{topic.name}/i
        score=0.0
      else
        score = b[0] / words.size.to_f
      end
      b[0] = score
      if score>max_score
        max_score=score
      end
      puts b[1] +":  "+ b[0].to_s
    end
    cat_buckets.each do |b|
      if max_score==0
        if b[1] =~ /#{topic.name}/i
          @topics.cats.each do |c|
            if c.id == b[2]
              puts "Pulling answers from: "+ c.name
              c.topics.each do |t|
                tname = t.name
                unless tname.index('(').nil?
                  tname.slice!(tname.index('(')..(tname.size-1))
                end
                @choices.push(t.name)
              end
            end
          end
        end
      else
        if b[0]>= max_score
          @topics.cats.each do |c|
            if c.id == b[2]
              puts "Pulling answers from: "+ c.name
              c.topics.each do |t|
                tname = t.name
                unless tname.index('(').nil?
                  tname.slice!(tname.index('(')..(tname.size-1))
                end
                @choices.push(t.name)
              end
            end
          end
        end
      end
    end

    while @choices.size < 4
      rando_cat = @topics.cats.offset(rand(@topics.cats.count)).first
      rando_top = rando_cat.topics.offset(rand(rando_cat.topics.count)).first
      x = @choices.index rando_top.name
      if x.nil?
        @choices.push(rando_top.name)
      end
    end
    mc = []
    mc[0] = @topic.name
    i = 1
    while i<4
      wrong = nil
      while wrong.nil?
        wrong = @choices[rand(@choices.size)]
        x= mc.index wrong
        if wrong[0..4] == 'User:'
          puts wrong
          x = nil
        end
        if x.nil? && wrong.length > 0
          mc[i] = wrong
          i+=1
        end
      end
    end

    return mc
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
