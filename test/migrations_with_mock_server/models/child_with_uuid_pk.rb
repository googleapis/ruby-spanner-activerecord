# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "composite_primary_keys"

module TestMigrationsWithMockServer
  class ChildWithUuidPk < ActiveRecord::Base
    # Register both primary key columns with composite_primary_keys
    self.primary_keys = :parentid, :childid
  end
end
