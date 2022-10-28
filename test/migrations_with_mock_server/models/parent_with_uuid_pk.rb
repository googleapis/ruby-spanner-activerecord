# Copyright 2022 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "composite_primary_keys"

module TestMigrationsWithMockServer
  class ParentWithUuidPk < ActiveRecord::Base
    self.primary_keys = :parentid
  end
end

