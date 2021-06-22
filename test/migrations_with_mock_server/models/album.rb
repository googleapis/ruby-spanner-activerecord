# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

module TestMigrationsWithMockServer
  class Album < ActiveRecord::Base
    belongs_to :singer
    has_many :tracks
  end
end
