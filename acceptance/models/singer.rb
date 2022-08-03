# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class Singer < ActiveRecord::Base
  has_many :albums, foreign_key: :singerid, dependent: :delete_all
  has_many :tracks, foreign_key: :singerid
end
