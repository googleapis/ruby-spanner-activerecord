class Firm < ActiveRecord::Base
  has_one :account
  has_many :departments, as: :resource
end
