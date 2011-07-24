class CatsController < ApplicationController

  def index
    @cats = Cat.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @cats }
    end
  end

  def get
    @cat = Cat.find_by_name(params[:name])

    # fetch and save if no topic
    Cat.transaction do
    if not @cat
      cats_topics = lookup(params[:name])
      @cat = Cat.create!(:name => params[:name])
      cats_topics.each do |topic|
        @cat.topics.find_or_create_by_name(topic[0]) unless @topic
      end
    end
    end

    render :text => @cat.to_yaml
    return

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @cat }
      format.json  { render :json => @cat }
    end
  end

  private

  def lookup(name)
    wiki_cat = Scraper.define do
      array :names
      array :urls
      process "#mw-pages li a", :names => :text, :urls => "@href"
      result  :names, :urls
    end

    wiki_cat.options[:user_agent] = "Mozilla/4.0"
    cats = wiki_cat.scrape(URI.parse("http://en.wikipedia.org/wiki/Category:#{name}"))
    cats_zip = cats[:names].zip(cats[:urls])
    return cats_zip
  end

end
