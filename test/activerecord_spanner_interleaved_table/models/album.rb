# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "composite_primary_keys"

module TestInterleavedTables
  class Album < ActiveRecord::Base
    self.primary_keys = :singerid, :albumid

    belongs_to :singer, foreign_key: :singerid
  end
end
