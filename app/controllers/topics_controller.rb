class TopicsController < ApplicationController

  def index
    @topics = Topic.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @topics }
    end
  end


  def get
    human_name = params[:name].gsub("_", " ")
    @term = Term.find_by_term(human_name)
    # fetch and save if no topic
    if @term.nil?
      puts "@term was nil"
      n = quick_lookup(params[:name])
      puts "after qwiki"
      @topic = Topic.find_by_name(n)
      if @topic.nil? or @topic.description.nil?
        puts "either nil" + params[:name]
        topic_details = lookup(params[:name])
        puts "post lookup"

        if @topic.nil?
          puts "topic nil"
          @topic = Topic.create(
            :name => (topic_details[:name] if topic_details[:name]),
            :img_url => (topic_details[:image][0] if topic_details[:image]),
            :description => (topic_details[:description][0] if topic_details[:description]))
          Term.create(:term => human_name, :topic_id => @topic.id)
        else
          puts "desc nil"
          @topic.update(
            :img_url => (topic_details[:image][0] if topic_details[:image]),
            :description => (topic_details[:description][0] if topic_details[:description]))
        end

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
          @cat.topics << @topic
        end
      end
      else
        @topic = Topic.find_by_id(@term.topic_id)

        if @topic.description.nil?
          topic_details = lookup(params[:name])

          @topic.update(
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
            @cat.topics << @topic
          end
        end
      end

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @topic }
      format.json  { render :json => @topic }
    end
  end

  def multiple_choice
    human_name = params[:name].gsub("_", " ")
    @topic = Topic.find_by_name(human_name.capitalize)
    if @topic
      @desc = @topic.description
      @wrong = []
      @test = Topic.find_by_name(human_name.capitalize, :include => [{:cats => :topics}])
      @test.cats.each do |c|
        c.topics.each do |t|
          @wrong.push(t)
        end
      end
      @mc = []
      @mc[0] = @topic.name
      for i in (1..3) do
        wrong = @wrong[rand(@wrong.size)]
        unless wrong.name == @topic.name
          @mc[i] = wrong.name
        end
      end
    else
      get
    end

  end

  private

  def quick_lookup(n)
    qwiki = Scraper.define do
      process "#firstHeading", :name => :text
      result  :name
    end
    puts "QWIKI running: "+URI.parse("http://en.wikipedia.org/wiki/#{n}").to_s
    article = qwiki.scrape(URI.parse("http://en.wikipedia.org/wiki/#{n}"))
    puts article
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
      process "#bodyContent >p", :description=>:text do |element|
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
