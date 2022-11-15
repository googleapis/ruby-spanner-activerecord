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

        def index_parts index
          index_parts = super
          index_parts << "null_filtered: #{index.null_filtered.inspect}" if index.null_filtered
          index_parts << "interleave_in: #{index.interleave_in.inspect}" if index.interleave_in
          index_parts << "storing: #{format_index_parts index.storing}" if index.storing.present?
          index_parts
        end
      end
    end
  end
end
