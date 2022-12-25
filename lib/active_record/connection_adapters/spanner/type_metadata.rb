# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Spanner
      class TypeMetadata < DelegateClass(SqlTypeMetadata)
        undef to_yaml if method_defined? :to_yaml

        include Deduplicable if defined?(Deduplicable)

        attr_reader :ordinal_position, :allow_commit_timestamp, :generated

        def initialize type_metadata, ordinal_position: nil, allow_commit_timestamp: nil, generated: nil
          super type_metadata
          @ordinal_position = ordinal_position
          @allow_commit_timestamp = allow_commit_timestamp
          @generated = generated
        end

        def == other
          other.is_a?(TypeMetadata) &&
            __getobj__ == other.__getobj__ &&
            ordinal_position == other.ordinal_position &&
            allow_commit_timestamp == other.allow_commit_timestamp &&
            generated == other.generated
        end
        alias eql? ==

        def hash
          TypeMetadata.hash ^
            __getobj__.hash ^
            ordinal_position.hash ^
            allow_commit_timestamp.hash ^
            generated.hash
        end

        private

        def deduplicated
          __setobj__ __getobj__.deduplicate
          super
        end
      end
    end
  end
end
