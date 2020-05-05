# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class Club < ActiveRecord::Base
  has_many :memberships
  has_many :members, through: :memberships
  has_many :favourites, -> { where(memberships: { favourite: true }) },
           through: :memberships, source: :member
end
