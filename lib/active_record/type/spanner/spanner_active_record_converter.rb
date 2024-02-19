# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

module ActiveRecord
  module Type
    module Spanner
      class SpannerActiveRecordConverter
        def self.serialize_with_transaction_isolation_level type, value, isolation_level
          if type.respond_to? :serialize_with_isolation_level
            type.serialize_with_isolation_level value, isolation_level
          elsif type.respond_to? :serialize
            type.serialize value
          else
            value
          end
        end

        ##
        # Converts an ActiveModel::Type to a Spanner type code.
        def self.convert_active_model_type_to_spanner type # rubocop:disable Metrics/CyclomaticComplexity
          # Unwrap the underlying object if the type is a DelegateClass.
          type = type.__getobj__ if type.respond_to? :__getobj__

          case type
          when NilClass then nil
          when ActiveModel::Type::Integer, ActiveModel::Type::BigInteger then :INT64
          when ActiveModel::Type::Boolean then :BOOL
          when ActiveModel::Type::String, ActiveModel::Type::ImmutableString then :STRING
          when ActiveModel::Type::Binary, ActiveRecord::Type::Spanner::Bytes then :BYTES
          when ActiveModel::Type::Float then :FLOAT64
          when ActiveModel::Type::Decimal then :NUMERIC
          when ActiveModel::Type::DateTime, ActiveModel::Type::Time, ActiveRecord::Type::Spanner::Time then :TIMESTAMP
          when ActiveModel::Type::Date then :DATE
          when ActiveRecord::Type::Json then :JSON
          when ActiveRecord::Type::Spanner::Array then [convert_active_model_type_to_spanner(type.element_type)]
          end
        end
      end
    end
  end
end
