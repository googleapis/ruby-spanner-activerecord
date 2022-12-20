# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "models/album"

class AlbumPartialDisabled < Album
  self.table_name = :albums

  if ActiveRecord::VERSION::MAJOR >= 7
    self.partial_inserts = false
  end
end
