# Copyright 2022 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class Album < ActiveRecord::Base
  self.primary_keys = :singerid, :albumid

  # `albums` is defined as INTERLEAVE IN PARENT `singers`. The primary key of `singers` is `singerid`.
  belongs_to :singer, foreign_key: :singerid

  # `tracks` is defined as INTERLEAVE IN PARENT `albums`. The primary key of `albums` is (`singerid`, `albumid`), but
  # only `albumid` is used by ActiveRecord as the primary key. The `singerid` column is defined as a `parent_key` of
  # `albums` (see also the `db/migrate/01_create_tables.rb` file).
  has_many :tracks, foreign_key: [:singerid, :albumid]
end