class Account < ActiveRecord::Base
  belongs_to :firm
  belongs_to :customer
  has_many :transactions
end

