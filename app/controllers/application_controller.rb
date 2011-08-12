class ApplicationController < ActionController::Base
  after_filter :set_access_control_headers
  
  protect_from_forgery

  def set_access_control_headers
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Request-Method'] = '*'
  end
end
