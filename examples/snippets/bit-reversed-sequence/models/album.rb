# Copyright 2023 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class Album < ActiveRecord::Base
  # `albums` is defined as INTERLEAVE IN PARENT `singers`.
  # The primary key of `singers` is `singerid`.
  belongs_to :singer, foreign_key: :singerid
end
