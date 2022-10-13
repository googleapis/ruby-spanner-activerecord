# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Spanner
      class SchemaDumper < ConnectionAdapters::SchemaDumper # :nodoc:
        def default_primary_key? column
          schema_type(column) == :integer
        end

        def prepare_column_options(column)
          super.tap do |spec|
            unless column.sql_type_metadata.allow_commit_timestamp.nil?
              spec[:allow_commit_timestamp] = column.sql_type_metadata.allow_commit_timestamp
            end
          end
        end
      end
    end
  end
end
