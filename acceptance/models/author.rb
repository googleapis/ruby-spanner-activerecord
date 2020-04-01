class Author < ActiveRecord::Base
  has_many :posts
  has_many :commnets, through: :posts
  belongs_to :organization
end
