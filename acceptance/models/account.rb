# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class Account < ActiveRecord::Base
  belongs_to :firm
  belongs_to :customer
  has_many :transactions

  alias_attribute :available_credit, :credit_limit
end
