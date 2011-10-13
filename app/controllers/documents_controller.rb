class DocumentsController < ApplicationController
    # GET /documents
  # GET /documents.xml
  def index
    @documents = Document.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @documents }
    end
  end

  # GET /documents/1
  # GET /documents/1.xml
  def show
    @document = Document.find(params[:id])
    @topic_identifiers = @document.topic_identifiers
    @answers = {}
    @topic_identifiers.each do |topic|
      @answers[topic.id] = ""
      Answer.all(:conditions => {:topic_id => topic.id}).each do |answer|
        @answers[topic.id] += "#{answer.name}\n"
      end
    end

    puts @answers.to_json

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @document }
    end
  end

  # GET /documents/new
  # GET /documents/new.xml
  def new

    @document = Document.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @document }
    end
  end

  # GET /documents/1/edit
  def edit
    @document = Document.find(params[:id])
  end

  # POST /documents
  # POST /documents.xml
  def create
    @document = Document.create!(params[:document])
    Document.parse_list(@document.id) unless @document.nil?

    respond_to do |format|
#      if @document.save
        format.html { redirect_to(@document, :notice => 'document was successfully created.') }
        format.xml  { render :xml => @document, :status => :created, :location => @document }
#      else
#        format.html { render :action => "new" }
#        format.xml  { render :xml => @document.errors, :status => :unprocessable_entity }
#      end
    end
  end

  def update
    @document = Document.find(params[:id])

    respond_to do |format|
      if @document.update_attributes(params[:document])
        format.html { redirect_to(@document, :notice => 'document was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @document.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /documents/1
  # DELETE /documents/1.xml
  def destroy
    @document = Document.find(params[:id])
    @document.destroy

    respond_to do |format|
      format.html { redirect_to(documents_url) }
      format.xml  { head :ok }
    end
  end


  ## THIS IS NOT A REAL METHOD!!! JUST A CSV EXPORT EXAMPLE ##
  def export_document_to_csv
    @document = Document.find_by_id(params[:id])
    return if @document.nil?

    csv_string_test = FasterCSV.generate do |csv|
      csv << ["term", "definition", "question", "incorrect answers"]

     @document.topic_identifiers.each do |ti|
        topic = Topic.find_by_id(ti.topic_id)
        answers = Answer.where("topic_id = ?",ti.topic_id)
        next if topic.nil?

        row = [ti.name, clean_markup_from_desc(topic.description), topic.question]
        unless answers.nil?
          answers.each do |a|
            row << a.name
          end
        end
        csv << row
      end
    end

    # send it to the browsah
    send_data csv_string_test,
              :type => 'text/csv; charset=iso-8859-1; header=present',
              :disposition => "attachment; filename=#{params[:file_name]}.csv"
  end

  private

  def clean_markup_from_desc(str)
    get_text = Scraper.define do
      process "p", :just_text => :text
      result :just_text
    end

    begin
      raw_text = get_text.scrape(str)
      raw_text.gsub! /\<[^>]*>\]/, ""
      raw_text.gsub! /\[[^]*]\]/, ""
      raw_text.gsub! /\([^)]*\)/, ""
      raw_text.gsub!(" ,", ",")
    rescue
      raw_text =  "ERROR!!"
    end

    return raw_text
  end
end
