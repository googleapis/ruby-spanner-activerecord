# Copyright 2023 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class Singer < ActiveRecord::Base
  # Set the sequence name so the ActiveRecord provider knows that it should let the database generate the primary key
  # value and return it using a `THEN RETURN id` clause.
  self.sequence_name = :singer_sequence

  # `albums` is defined as INTERLEAVE IN PARENT `singers`.
  # The primary key of `albums` is (`singerid`, `albumid`).
  has_many :albums, foreign_key: :singerid
end
