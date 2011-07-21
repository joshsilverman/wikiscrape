class Link < ActiveRecord::Base
  attr_accessible :topic_id, :ref_id

  belongs_to :topic
  belongs_to :ref, :class_name => 'Topic'
end
