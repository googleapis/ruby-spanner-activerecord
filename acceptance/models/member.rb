# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class Member < ActiveRecord::Base
  has_one :membership
  has_one :club, through: :membership
  has_one :favourite_club, -> { where "memberships.favourite = ?", true },
          through: :membership, source: :club
  belongs_to :member_type
end
