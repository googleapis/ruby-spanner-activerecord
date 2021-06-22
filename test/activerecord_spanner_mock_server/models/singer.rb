# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

module MockServerTests
  class Singer < ActiveRecord::Base
    has_many :albums
  end
end
