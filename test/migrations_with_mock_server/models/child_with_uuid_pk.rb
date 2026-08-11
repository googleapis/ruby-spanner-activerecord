# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

module TestMigrationsWithMockServer
  class ChildWithUuidPk < ActiveRecord::Base
    self.primary_key = [:parentid, :childid]
  end
end
