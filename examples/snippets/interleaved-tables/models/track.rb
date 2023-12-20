# Copyright 2023 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class Track < ActiveRecord::Base
  # `tracks` is defined as INTERLEAVE IN PARENT `albums`.
  # The primary key of `albums` is (`singerid`, `albumid`).
  # Rails 7.1 requires a composite primary key in a belongs_to relationship to be specified as query_constraints.
  belongs_to :album, query_constraints: [:singerid, :albumid]

  # `tracks` also has a `singerid` column that can be used to associate a Track with a Singer.
  belongs_to :singer, foreign_key: :singerid

  # Override the default initialize method to automatically set the singer attribute when an album is given.
  def initialize attributes = nil
    super
    self.singer ||= album&.singer
  end

  def album=value
    super
    # Ensure the singer of this track is equal to the singer of the album that is set.
    self.singer = value&.singer
  end
end
