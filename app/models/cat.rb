class Cat < ActiveRecord::Base

  has_and_belongs_to_many :topics, :uniq => true
end