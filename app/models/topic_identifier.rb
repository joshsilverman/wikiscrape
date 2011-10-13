class TopicIdentifier < ActiveRecord::Base
  has_and_belongs_to_many :documents
  belongs_to :topic
end
