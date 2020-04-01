class Address < ActiveRecord::Base
  has_one :author
end
