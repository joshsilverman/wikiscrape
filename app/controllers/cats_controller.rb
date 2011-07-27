class CatsController < ApplicationController

  def index
    @cats = Cat.all

    respond_to do |format|
      format.html  index.html.erb
      format.xml  { render :xml => @cats }
    end
  end

end
