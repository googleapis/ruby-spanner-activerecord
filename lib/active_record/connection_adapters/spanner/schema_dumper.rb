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

        def header(stream)
          str = StringIO.new
          super(str)
          stream.puts <<HEADER
#{str.string.rstrip}
  connection.start_batch_ddl

HEADER
        end

        def trailer(stream)
          stream.puts <<TRAILER
  connection.run_batch
rescue
  abort_batch
  raise
TRAILER
          super
        end
      end
    end
  end
end
