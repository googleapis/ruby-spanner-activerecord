# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class Album < ActiveRecord::Base
  # The relationship with singer is not really a foreign key, but an INTERLEAVE IN relationship. We still need to
  # use the `foreign_key` attribute to indicate which column to use for the relationship.
  belongs_to :singer, foreign_key: "singerid"
  has_many :tracks, foreign_key: "albumid", dependent: :delete_all
end
