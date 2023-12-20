# Copyright 2023 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class Album < ActiveRecord::Base
  # `albums` is defined as INTERLEAVE IN PARENT `singers`.
  # The primary key of `singers` is `singerid`.
  belongs_to :singer, foreign_key: :singerid

  # `tracks` is defined as INTERLEAVE IN PARENT `albums`.
  # The primary key of `albums` is (`singerid`, `albumid`).
  # Rails 7.1 requires using query_constraints to define a composite foreign key.
  has_many :tracks, query_constraints: [:singerid, :albumid]
end
