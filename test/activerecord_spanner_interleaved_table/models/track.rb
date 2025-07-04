# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "composite_primary_keys"

module TestInterleavedTables
  class Track < ActiveRecord::Base
    self.primary_keys = :singerid, :albumid, :trackid

    belongs_to :album, :class_name => "Album", foreign_key: [:singerid, :albumid]
    belongs_to :singer, :class_name => "Singer", foreign_key: :singerid

    def album=value
      super
      # Ensure the singer of this track is equal to the singer of the album that is set.
      self.singer = value&.singer
    end
  end
end
