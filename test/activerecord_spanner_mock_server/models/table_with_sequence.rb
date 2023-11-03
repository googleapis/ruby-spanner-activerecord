# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

module MockServerTests
  class TableWithSequence < ActiveRecord::Base
    self.table_name = :table_with_sequence
    self.sequence_name = :test_sequence
  end
end
