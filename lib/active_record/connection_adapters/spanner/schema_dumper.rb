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

        def prepare_column_options column
          spec = super

          unless column.sql_type_metadata.allow_commit_timestamp.nil?
            spec[:allow_commit_timestamp] = column.sql_type_metadata.allow_commit_timestamp
          end

          if column.virtual?
            spec[:as] = extract_expression_for_virtual_column column
            spec[:stored] = true
            spec = { type: schema_type(column).inspect }.merge! spec
          end

          spec[:array] = true if column.sql_type.start_with?('ARRAY<')

          spec
        end

        def header stream
          str = StringIO.new
          super str
          stream.puts <<~HEADER
            #{str.string.rstrip}
              connection.start_batch_ddl

          HEADER
        end

        def trailer stream
          stream.puts <<~TRAILER
              connection.run_batch
            rescue
              abort_batch
              raise
          TRAILER
          super
        end

        def index_parts index
          index_parts = super
          index_parts << "null_filtered: #{index.null_filtered.inspect}" if index.null_filtered
          index_parts << "interleave_in: #{index.interleave_in.inspect}" if index.interleave_in
          index_parts << "storing: #{format_index_parts index.storing.sort}" if index.storing.present?
          index_parts
        end

        private

        def column_spec_for_primary_key column
          spec = super
          spec.except! :limit if default_primary_key? column
          spec
        end

        def extract_expression_for_virtual_column column
          column.default_function.inspect
        end
      end
    end
  end
end
