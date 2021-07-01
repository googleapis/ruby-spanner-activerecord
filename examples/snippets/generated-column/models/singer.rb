# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class Singer < ActiveRecord::Base
  # `albums` is defined as INTERLEAVE IN PARENT `singers`. The primary key of `albums` is (`singerid`, `albumid`), but
  # only `albumid` is used by ActiveRecord as the primary key. The `singerid` column is defined as a `parent_key` of
  # `albums` (see also the `db/migrate/01_create_tables.rb` file).
  has_many :albums, foreign_key: "singerid"

  # `tracks` is defined as INTERLEAVE IN PARENT `albums`. The primary key of `tracks` is
  # (`singerid`, `albumid`, `trackid`), but only `trackid` is used by ActiveRecord as the primary key. The `singerid`
  # and `albumid` columns are defined as `parent_key` of `tracks` (see also the `db/migrate/01_create_tables.rb` file).
  # The `singerid` column can therefore be used to associate tracks with a singer without the need to go through albums.
  # Note also that the inclusion of `singerid` as a column in `tracks` is required in order to make `tracks` a child
  # table of `albums` which has primary key (`singerid`, `albumid`).
  has_many :tracks, foreign_key: "singerid"
end
