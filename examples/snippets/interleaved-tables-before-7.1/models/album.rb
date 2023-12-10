# Copyright 2022 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "composite_primary_keys"

class Album < ActiveRecord::Base
  # Use the `composite_primary_key` gem to create a composite primary key definition for the model.
  self.primary_keys = :singerid, :albumid

  # `albums` is defined as INTERLEAVE IN PARENT `singers`.
  # The primary key of `singers` is `singerid`.
  belongs_to :singer, foreign_key: :singerid

  # `tracks` is defined as INTERLEAVE IN PARENT `albums`.
  # The primary key of `albums` is (`singerid`, `albumid`).
  has_many :tracks, foreign_key: [:singerid, :albumid]
end
