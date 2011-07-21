class LinksController < ApplicationController
  def create
    @link = Link.new(params[:link])
    if @link.save
      redirect_to root_url, :notice => "Successfully created link."
    else
      render :action => 'new'
    end
  end

  def destroy
    @link = Link.find(params[:id])
    @link.destroy
    redirect_to root_url, :notice => "Successfully destroyed link."
  end
end
