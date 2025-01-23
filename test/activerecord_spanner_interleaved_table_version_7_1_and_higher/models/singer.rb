# Copyright 2023 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

module TestInterleavedTables_7_1_AndHigher
  class Singer < ActiveRecord::Base
    has_many :albums, foreign_key: :singerid
  end
end
