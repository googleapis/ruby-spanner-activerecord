class Customer < ActiveRecord::Base
  has_many :accounts
end
