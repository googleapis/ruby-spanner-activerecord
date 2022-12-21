# Copyright 2022 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Spanner
      class Column < ConnectionAdapters::Column
        def has_default? # rubocop:disable Naming/PredicateName
          super && !virtual?
        end

        def virtual?
          sql_type_metadata.generated
        end
      end
    end
  end
end
