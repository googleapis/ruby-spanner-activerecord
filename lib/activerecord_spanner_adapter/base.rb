# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

module ActiveRecord
  class TableMetadata # :nodoc:
    # This attr_reader is private in ActiveRecord 6.0.x and public in 6.1.x. This makes sure it is always available in
    # the Spanner adapter.
    attr_reader :arel_table
  end

  class Base
    # Creates an object (or multiple objects) and saves it to the database. This method will use mutations instead
    # of DML if there is no active transaction, or if the active transaction has been created with the option
    # isolation: :buffered_mutations.
    def self.create! attributes = nil, &block
      return super unless spanner_adapter?
      return super if active_transaction?

      transaction isolation: :buffered_mutations do
        return super
      end
    end

    def self.create attributes = nil, &block
      return super unless spanner_adapter?
      return super if active_transaction?

      transaction isolation: :buffered_mutations do
        return super
      end
    end

    def self.spanner_adapter?
      connection.adapter_name == "spanner"
    end

    def self.buffered_mutations?
      spanner_adapter? && connection&.current_spanner_transaction&.isolation == :buffered_mutations
    end

    def self._insert_record values
      return super unless buffered_mutations?

      primary_key = self.primary_key
      primary_key_value = nil

      if primary_key && values.is_a?(Hash)
        primary_key_value = values[primary_key]

        if !primary_key_value && prefetch_primary_key?
          primary_key_value = next_sequence_value
          values[primary_key] = primary_key_value
        end
      end

      metadata = TableMetadata.new self, arel_table
      columns, grpc_values = _create_grpc_values_for_insert metadata, values

      mutation = Google::Cloud::Spanner::V1::Mutation.new(
        insert: Google::Cloud::Spanner::V1::Mutation::Write.new(
          table: arel_table.name,
          columns: columns,
          values: [grpc_values.list_value]
        )
      )
      connection.current_spanner_transaction.buffer mutation

      primary_key_value
    end

    # Deletes all records of this class. This method will use mutations instead of DML if there is no active
    # transaction, or if the active transaction has been created with the option isolation: :buffered_mutations.
    def self.delete_all
      return super unless spanner_adapter?
      return super if active_transaction?

      transaction isolation: :buffered_mutations do
        return super
      end
    end

    def self.active_transaction?
      current_transaction = connection.current_transaction
      !(current_transaction.nil? || current_transaction.is_a?(ConnectionAdapters::NullTransaction))
    end

    def self.unwrap_attribute attr_or_value
      if attr_or_value.is_a? ActiveModel::Attribute
        attr_or_value.value
      else
        attr_or_value
      end
    end

    # Updates the given attributes of the object in the database. This method will use mutations instead
    # of DML if there is no active transaction, or if the active transaction has been created with the option
    # isolation: :buffered_mutations.
    def update attributes
      return super unless self.class.spanner_adapter?
      return super if self.class.active_transaction?

      transaction isolation: :buffered_mutations do
        return super
      end
    end

    # Deletes the object in the database. This method will use mutations instead
    # of DML if there is no active transaction, or if the active transaction has been created with the option
    # isolation: :buffered_mutations.
    def destroy
      return super unless self.class.spanner_adapter?
      return super if self.class.active_transaction?

      transaction isolation: :buffered_mutations do
        return super
      end
    end

    private

    def self._create_grpc_values_for_insert metadata, values
      serialized_values = []
      columns = []
      values.each_pair do |k, v|
        v = unwrap_attribute v
        type = metadata.type k
        serialized_values << (type.method(:serialize).arity < 0 ? type.serialize(v, :mutation) : type.serialize(v))
        columns << metadata.arel_table[k].name
      end
      [columns, Google::Protobuf::Value.new(list_value:
        Google::Protobuf::ListValue.new(
          values: serialized_values.map do |value|
            Google::Cloud::Spanner::Convert.object_to_grpc_value value
          end
        ))]
    end
    private_class_method :_create_grpc_values_for_insert

    def _update_row attribute_names, attempted_action = "update"
      return super unless self.class.buffered_mutations?

      if locking_enabled?
        _execute_version_check attempted_action
        attribute_names << self.class.locking_column
        self[self.class.locking_column] += 1
      end

      metadata = TableMetadata.new self.class, self.class.arel_table
      values = attributes_with_values attribute_names
      columns, grpc_values = _create_grpc_values_for_update metadata, values

      mutation = Google::Cloud::Spanner::V1::Mutation.new(
        update: Google::Cloud::Spanner::V1::Mutation::Write.new(
          table: self.class.arel_table.name,
          columns: columns,
          values: [grpc_values.list_value]
        )
      )
      self.class.connection.current_spanner_transaction.buffer mutation
      1 # Affected rows
    end

    def _create_grpc_values_for_update metadata, values
      constraints = {}
      keys = self.class.primary_and_parent_key
      keys.each do |key|
        constraints[key] = attribute_in_database key
      end

      # Use both the where values + the values that are actually set.
      all_values = [constraints, values]
      all_serialized_values = []
      all_columns = []
      all_values.each do |h|
        h.each_pair do |k, v|
          type = metadata.type k
          v = self.class.unwrap_attribute v
          has_serialize_options = type.method(:serialize).arity < 0
          all_serialized_values << (has_serialize_options ? type.serialize(v, :mutation) : type.serialize(v))
          all_columns << metadata.arel_table[k].name
        end
      end
      [all_columns, Google::Protobuf::Value.new(list_value:
        Google::Protobuf::ListValue.new(
          values: all_serialized_values.map do |value|
            Google::Cloud::Spanner::Convert.object_to_grpc_value value
          end
        ))]
    end

    def destroy_row
      return super unless self.class.buffered_mutations?

      _delete_row
    end

    def _delete_row
      return super unless self.class.buffered_mutations?
      if locking_enabled?
        _execute_version_check "destroy"
      end

      metadata = TableMetadata.new self.class, self.class.arel_table
      keys = self.class.primary_and_parent_key
      serialized_values = serialize_keys metadata, keys
      list_value = Google::Protobuf::ListValue.new(
        values: serialized_values.map do |value|
          Google::Cloud::Spanner::Convert.object_to_grpc_value value
        end
      )
      mutation = Google::Cloud::Spanner::V1::Mutation.new(
        delete: Google::Cloud::Spanner::V1::Mutation::Delete.new(
          table: self.class.arel_table.name,
          key_set: { keys: [list_value] }
        )
      )
      self.class.connection.current_spanner_transaction.buffer mutation
      1 # Affected rows
    end

    def serialize_keys metadata, keys
      serialized_values = []
      keys.each do |key|
        type = metadata.type key
        has_serialize_options = type.method(:serialize).arity < 0
        serialized_values << type.serialize(attribute_in_database(key), :mutation) if has_serialize_options
        serialized_values << type.serialize(attribute_in_database(key)) unless has_serialize_options
      end
      serialized_values
    end

    def _execute_version_check attempted_action
      locking_column = self.class.locking_column
      previous_lock_value = read_attribute_before_type_cast locking_column

      # We need to check the version using a SELECT query, as a mutation cannot include a WHERE clause.
      sql = "SELECT 1 FROM `#{self.class.arel_table.name}` " \
              "WHERE `#{self.class.primary_key}` = @id AND `#{locking_column}` = @lock_version"
      params = { "id" => id_in_database, "lock_version" => previous_lock_value }
      param_types = { "id" => :INT64, "lock_version" => :INT64 }
      locked_row = self.class.connection.raw_connection.execute_query sql, params: params, types: param_types
      raise ActiveRecord::StaleObjectError.new(self, attempted_action) unless locked_row.rows.any?
    end
  end
end
