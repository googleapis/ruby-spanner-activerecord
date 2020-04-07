class Account < ActiveRecord::Base
  belongs_to :firm
  belongs_to :customer
  has_many :transactions

  alias_attribute :available_credit, :credit_limit
end
