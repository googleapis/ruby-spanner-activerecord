# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class Track < ActiveRecord::Base
  # Register both primary key columns with composite_primary_keys
  self.primary_keys = :singerid, :albumid, :trackid

  belongs_to :album, foreign_key: [:singerid, :albumid]
  belongs_to :singer, foreign_key: :singerid, counter_cache: true

  def initialize attributes = nil
    super
    self.singer ||= self.album&.singer
  end

  def album=value
    super
    self.singer = value&.singer
  end
end
