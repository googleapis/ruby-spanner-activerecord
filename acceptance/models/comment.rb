# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class Comment < ActiveRecord::Base
  belongs_to :post, counter_cache: true
end
