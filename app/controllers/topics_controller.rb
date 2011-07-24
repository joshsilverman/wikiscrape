class TopicsController < ApplicationController

  def index
    @topics = Topic.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @topics }
    end
  end


  def get
    @topic = Topic.find_by_name(params[:name])

    # fetch and save if no topic
    if not @topic or @topic.description.nil?
      topic_details = lookup(params[:name])
      @topic = Topic.create(
        :name => params[:name],
        :img_url => topic_details[:image],
        :description => topic_details[:description])
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
      process "#catlinks > span > a", :catlinks => "@src"

      result  :image, :description, :follow, :catlinks
    end

    article = wiki_article.scrape(URI.parse("http://en.wikipedia.org/wiki/#{name}"))

    # follow "may refer to:"
    if article.description and article.description.size > 0 and (article.description[description_index] =~ /may refer to:$/)
      if article.follow.length > 1
        article = wiki_article.scrape(URI.parse("http://en.wikipedia.org#{article.follow[0]}"))
      end
    end

    

    topic = {:topic => name, :description => "", :image => ""}
    topic[:description] = article.description[description_index]  if article.description and article.description.size > 0
    topic[:image] = article.image[0] if article.image and article.image.size > 0
    topic[:catlinks] = article.image[0] if article.image and article.image.size > 0

    return topic
  end

  def legal_lookup
  end

  def med_lookup
  end

  def bio_lookup
  end
end
