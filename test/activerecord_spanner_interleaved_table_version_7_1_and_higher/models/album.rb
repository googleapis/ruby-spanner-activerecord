# Copyright 2023 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

module TestInterleavedTables_7_1_AndHigher
  class Album < ActiveRecord::Base
    # self.primary_keys = :singerid, :albumid

    belongs_to :singer, foreign_key: :singerid

    # `tracks` is defined as INTERLEAVE IN PARENT `albums`. The primary key of `albums` is (`singerid`, `albumid`).
    has_many :tracks, query_constraints: [:singerid, :albumid]
  end
end
