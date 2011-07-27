# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
Wikiscrape::Application.initialize!

# Use built in html parser for scrapi instead of Tidy gem
Scraper::Base.parser :html_parser