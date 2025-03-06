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
        # rubocop:disable Style/OptionalBooleanParameter
        def initialize(name, default, sql_type_metadata = nil, null = true,
                       default_function = nil, collation: nil, comment: nil,
                       primary_key: false, **)
          # rubocop:enable Style/OptionalBooleanParameter
          super
          @primary_key = primary_key
        end

        def auto_incremented_by_db?
          sql_type_metadata.is_identity
        end

        def has_default?
          super && !virtual?
        end

        def virtual?
          sql_type_metadata.generated
        end

        def primary_key?
          @primary_key
        end
      end
    end
  end
end
