# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "composite_primary_keys"

module TestInterleavedTables
  class Track < ActiveRecord::Base
    self.primary_keys = :singerid, :albumid, :trackid

    # Note that the actual primary key of album consists of both (singerid, albumid) columns.
    belongs_to :album, foreign_key: [:singerid, :albumid]
    belongs_to :singer, foreign_key: :singerid

    def album=value
      self.singer = value.singer
      super
    end
  end
end
