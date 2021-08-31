# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "securerandom"
require "google/cloud/spanner"
require "spanner_client_ext"
require "active_record/connection_adapters/abstract_adapter"
require "active_record/connection_adapters/spanner/database_statements"
require "active_record/connection_adapters/spanner/schema_statements"
require "active_record/connection_adapters/spanner/schema_cache"
require "active_record/connection_adapters/spanner/schema_definitions"
require "active_record/connection_adapters/spanner/type_metadata"
require "active_record/connection_adapters/spanner/quoting"
require "active_record/type/spanner/array"
require "active_record/type/spanner/bytes"
require "active_record/type/spanner/spanner_active_record_converter"
require "active_record/type/spanner/time"
require "arel/visitors/spanner"
require "activerecord_spanner_adapter/base"
require "activerecord_spanner_adapter/connection"
require "activerecord_spanner_adapter/errors"
require "activerecord_spanner_adapter/information_schema"
require "activerecord_spanner_adapter/primary_key"
require "activerecord_spanner_adapter/transaction"

module ActiveRecord
  module ConnectionHandling # :nodoc:
    def spanner_connection config
      connection = ActiveRecordSpannerAdapter::Connection.new config
      connection.connect!
      ConnectionAdapters::SpannerAdapter.new connection, logger, nil, config
    rescue Google::Cloud::Error => error
      if error.instance_of? Google::Cloud::NotFoundError
        raise ActiveRecord::NoDatabaseError
      end
      raise error
    end
  end

  module ConnectionAdapters
    module AbstractPool
      def get_schema_cache connection
        @schema_cache ||= SpannerSchemaCache.new connection
        @schema_cache.connection = connection
        @schema_cache
      end
    end

    class SpannerAdapter < AbstractAdapter
      ADAPTER_NAME = "spanner".freeze
      NATIVE_DATABASE_TYPES = {
        primary_key:  "INT64",
        parent_key:   "INT64",
        string:       { name: "STRING", limit: "MAX" },
        text:         { name: "STRING", limit: "MAX" },
        integer:      { name: "INT64" },
        bigint:       { name: "INT64" },
        float:        { name: "FLOAT64" },
        decimal:      { name: "NUMERIC" },
        numeric:      { name: "NUMERIC" },
        datetime:     { name: "TIMESTAMP" },
        time:         { name: "TIMESTAMP" },
        date:         { name: "DATE" },
        binary:       { name: "BYTES", limit: "MAX" },
        boolean:      { name: "BOOL" },
        json:         { name: "JSON" }
      }.freeze

      include Spanner::Quoting
      include Spanner::DatabaseStatements
      include Spanner::SchemaStatements

      def initialize connection, logger, connection_options, config
        super connection, logger, config
        @connection_options = connection_options
      end

      def max_identifier_length
        128
      end

      def native_database_types
        NATIVE_DATABASE_TYPES
      end

      # Database

      def self.database_exists? config
        connection = ActiveRecordSpannerAdapter::Connection.new config
        connection.connect!
        true
      rescue ActiveRecord::NoDatabaseError
        false
      end

      # Connection management

      def active?
        @connection.active?
      end

      def disconnect!
        super
        @connection.disconnect!
      end

      def reset!
        super
        @connection.reset!
      end
      alias reconnect! reset!

      # Spanner Connection API
      delegate :ddl_batch, :ddl_batch?, :start_batch_ddl, :abort_batch, :run_batch, to: :@connection

      def current_spanner_transaction
        @connection.current_transaction
      end

      # Supported features

      def supports_bulk_alter?
        true
      end

      def supports_common_table_expressions?
        true
      end

      def supports_explain?
        false
      end

      def supports_foreign_keys?
        true
      end

      def supports_index_sort_order?
        true
      end

      def supports_insert_on_conflict?
        true
      end
      alias supports_insert_on_duplicate_skip? supports_insert_on_conflict?
      alias supports_insert_on_duplicate_update? supports_insert_on_conflict?
      alias supports_insert_conflict_target? supports_insert_on_conflict?

      def supports_insert_returning?
        true
      end

      def supports_multi_insert?
        true
      end

      def supports_optimizer_hints?
        true
      end

      def supports_primary_key?
        true
      end

      def prefetch_primary_key? _table_name = nil
        true
      end

      # Generate next sequence number for primary key
      def next_sequence_value _sequence_name
        SecureRandom.uuid.gsub("-", "").hex & 0x7FFFFFFFFFFFFFFF
      end

      def arel_visitor
        Arel::Visitors::Spanner.new self
      end

      private

      def initialize_type_map m = type_map
        m.register_type "BOOL", Type::Boolean.new
        register_class_with_limit(
          m, %r{^BYTES}i, ActiveRecord::Type::Spanner::Bytes
        )
        m.register_type "DATE", Type::Date.new
        m.register_type "FLOAT64", Type::Float.new
        m.register_type "NUMERIC", Type::Decimal.new
        m.register_type "INT64", Type::Integer.new(limit: 8)
        register_class_with_limit m, %r{^STRING}i, Type::String
        m.register_type "TIMESTAMP", ActiveRecord::Type::Spanner::Time.new
        m.register_type "JSON", ActiveRecord::Type::Json.new

        register_array_types m
      end

      def register_array_types m
        m.register_type %r{^ARRAY<BOOL>}i, Type::Spanner::Array.new(Type::Boolean.new)
        m.register_type %r{^ARRAY<BYTES\((MAX|d+)\)>}i, Type::Spanner::Array.new(Type::Binary.new)
        m.register_type %r{^ARRAY<DATE>}i, Type::Spanner::Array.new(Type::Date.new)
        m.register_type %r{^ARRAY<FLOAT64>}i, Type::Spanner::Array.new(Type::Float.new)
        m.register_type %r{^ARRAY<NUMERIC>}i, Type::Spanner::Array.new(Type::Decimal.new)
        m.register_type %r{^ARRAY<INT64>}i, Type::Spanner::Array.new(Type::Integer.new(limit: 8))
        m.register_type %r{^ARRAY<STRING\((MAX|d+)\)>}i, Type::Spanner::Array.new(Type::String.new)
        m.register_type %r{^ARRAY<TIMESTAMP>}i, Type::Spanner::Array.new(ActiveRecord::Type::Spanner::Time.new)
        m.register_type %r{^ARRAY<JSON>}i, Type::Spanner::Array.new(ActiveRecord::Type::Json.new)
      end

      def extract_limit sql_type
        value = /\((.*)\)/.match sql_type
        return unless value

        value[1] == "MAX" ? "MAX" : value[1].to_i
      end

      def translate_exception exception, message:, sql:, binds:
        if exception.is_a? Google::Cloud::FailedPreconditionError
          case exception.message
          when /.*does not specify a non-null value for these NOT NULL columns.*/,
               /.*must not be NULL.*/
            NotNullViolation.new message, sql: sql, binds: binds
          else
            super
          end
        else
          super
        end
      end
    end
  end
end
