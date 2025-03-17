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

        attr_reader :ordinal_position
        attr_reader :allow_commit_timestamp
        attr_reader :generated
        attr_reader :is_identity

        def initialize type_metadata, ordinal_position: nil, allow_commit_timestamp: nil, generated: nil,
                       is_identity: false
          super type_metadata
          @ordinal_position = ordinal_position
          @allow_commit_timestamp = allow_commit_timestamp
          @generated = generated
          @is_identity = is_identity
        end

        def == other
          other.is_a?(TypeMetadata) &&
            __getobj__ == other.__getobj__ &&
            ordinal_position == other.ordinal_position &&
            allow_commit_timestamp == other.allow_commit_timestamp &&
            generated == other.generated &&
            is_identity == other.is_identity
        end
        alias eql? ==

        def hash
          [TypeMetadata.name, __getobj__, ordinal_position, allow_commit_timestamp, generated, is_identity].hash
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
