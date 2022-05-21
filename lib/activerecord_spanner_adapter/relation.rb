# Copyright 2022 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

module ActiveRecord
  module CpkExtension
    def cpk_subquery stmt
      return super unless spanner_adapter?
      cpk_exists_subquery stmt
    end
  end

  class Relation
    prepend CpkExtension
  end
end
