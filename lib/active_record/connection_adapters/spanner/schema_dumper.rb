# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Spanner
      class SchemaDumper < ConnectionAdapters::SchemaDumper # :nodoc:
        def default_primary_key? column
          schema_type(column) == :integer
        end
      end
    end
  end
end
