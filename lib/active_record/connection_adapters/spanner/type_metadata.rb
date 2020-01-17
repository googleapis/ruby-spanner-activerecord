# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Spanner
      class TypeMetadata < DelegateClass(SqlTypeMetadata)
        undef to_yaml if method_defined? :to_yaml

        attr_reader :ordinal_position

        def initialize type_metadata, ordinal_position: nil
          super type_metadata
          @ordinal_position = ordinal_position
        end

        def == other
          other.is_a?(TypeMetadata) &&
            __getobj__ == other.__getobj__ &&
            ordinal_position == other.ordinal_position
        end
        alias eql? ==

        def hash
          TypeMetadata.hash ^
            __getobj__.hash ^
            ordinal_position.hash
        end
      end
    end
  end
end
