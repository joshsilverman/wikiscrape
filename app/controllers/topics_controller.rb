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
    @topic = Topic.find_by_name(human_name)

    # fetch and save if no topic
    if @topic.nil? or @topic.description.nil?
      topic_details = lookup(params[:name])

      if @topic.nil?
        @topic = Topic.create(
          :name => human_name,
          :img_url => (topic_details[:image][0] if topic_details[:image]),
          :description => (topic_details[:description][0] if topic_details[:description]))
      else
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

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @topic }
      format.json  { render :json => @topic }
    end
  end

  private

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
      process ".infobox img, .thumb img", :image => "@src"
      process "#bodyContent>ul>li>a", :follow => "@href"
      process "#catlinks span a", :catlinks => :text
#      process "a", :catlinks => :text

      result  :image, :description, :follow, :catlinks
    end

    article = wiki_article.scrape(URI.parse("http://en.wikipedia.org/wiki/#{name}"))

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
