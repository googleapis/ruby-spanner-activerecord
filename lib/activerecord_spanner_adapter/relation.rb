# Copyright 2022 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

module ActiveRecord
  module CpkExtension
    def cpk_subquery stmt
      return super unless spanner_adapter?
      # The composite_primary_key gem will by default generate WHERE clauses using an IN clause with a multi-column
      # sub select, e.g.: SELECT * FROM my_table WHERE (id1, id2) IN (SELECT id1, id2 FROM my_table WHERE ...).
      # This is not supported in Cloud Spanner. Instead, composite_primary_key should generate an EXISTS clause.
      cpk_exists_subquery stmt
    end
  end

  class Relation
    prepend CpkExtension
  end
end
