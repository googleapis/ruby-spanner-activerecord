# Copyright 2022 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class Singer < ActiveRecord::Base
  # `albums` is defined as INTERLEAVE IN PARENT `singers`.
  # The primary key of `albums` is (`singerid`, `albumid`).
  has_many :albums, foreign_key: :singerid

  # `tracks` is defined as INTERLEAVE IN PARENT `albums`.
  # The primary key of `tracks` is [`singerid`, `albumid`, `trackid`].
  # The `singerid` column can be used to associate tracks with a singer without the need to go through albums.
  # Note also that the inclusion of `singerid` as a column in `tracks` is required in order to make `tracks` a child
  # table of `albums` which has primary key (`singerid`, `albumid`).
  has_many :tracks, foreign_key: :singerid
end
