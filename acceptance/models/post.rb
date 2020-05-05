# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class Post < ActiveRecord::Base
  belongs_to :author
  has_many :comments
end
