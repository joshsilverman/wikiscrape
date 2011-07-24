class Topic < ActiveRecord::Base
  
  has_and_belongs_to_many :cats, :uniq => true

  has_many :links
  has_many :refs, :through => :links
end
