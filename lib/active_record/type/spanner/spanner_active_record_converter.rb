# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "active_record/type/spanner/array"
require "active_record/type/spanner/bytes"
require "active_record/type/spanner/time"
require "active_record/type/spanner/uuid"

module ActiveRecord
  module Type
    module Spanner
      class SpannerActiveRecordConverter
        TYPE_MAP = {
          ActiveModel::Type::Integer => :INT64,
          ActiveModel::Type::BigInteger => :INT64,
          ActiveModel::Type::Boolean => :BOOL,
          ActiveModel::Type::String => :STRING,
          ActiveModel::Type::ImmutableString => :STRING,
          ActiveModel::Type::Binary => :BYTES,
          ActiveRecord::Type::Spanner::Bytes => :BYTES,
          ActiveModel::Type::Float => :FLOAT64,
          ActiveModel::Type::Decimal => :NUMERIC,
          ActiveModel::Type::DateTime => :TIMESTAMP,
          ActiveModel::Type::Time => :TIMESTAMP,
          ActiveRecord::Type::Spanner::Time => :TIMESTAMP,
          ActiveModel::Type::Date => :DATE,
          ActiveRecord::Type::Json => :JSON,
          ActiveRecord::Type::Spanner::Uuid => :UUID
        }.freeze
        private_constant :TYPE_MAP

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
        def self.convert_active_model_type_to_spanner type
          return nil if type.nil?

          # Unwrap the underlying object if the type is a DelegateClass.
          type = type.__getobj__ if type.respond_to? :__getobj__

          TYPE_MAP[type.class] || fallback_convert_active_model_type_to_spanner(type)
        end

        def self.fallback_convert_active_model_type_to_spanner type # rubocop:disable Metrics/CyclomaticComplexity
          case type
          when NilClass then nil
          when ActiveRecord::Type::Spanner::Array then [convert_active_model_type_to_spanner(type.element_type)]
          when ActiveModel::Type::Integer, ActiveModel::Type::BigInteger then :INT64
          when ActiveModel::Type::Boolean then :BOOL
          when ActiveModel::Type::String, ActiveModel::Type::ImmutableString then :STRING
          when ActiveModel::Type::Binary, ActiveRecord::Type::Spanner::Bytes then :BYTES
          when ActiveModel::Type::Float then :FLOAT64
          when ActiveModel::Type::Decimal then :NUMERIC
          when ActiveModel::Type::DateTime, ActiveModel::Type::Time, ActiveRecord::Type::Spanner::Time then :TIMESTAMP
          when ActiveModel::Type::Date then :DATE
          when ActiveRecord::Type::Json then :JSON
          when ActiveRecord::Type::Spanner::Uuid then :UUID
          end
        end
        private_class_method :fallback_convert_active_model_type_to_spanner
      end
    end
  end
end
