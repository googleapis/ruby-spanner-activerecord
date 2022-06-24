# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "activerecord_spanner_adapter/relation"

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
      return super unless buffered_mutations? || (primary_key && values.is_a?(Hash))

      return _buffer_record values, :insert if buffered_mutations?

      primary_key_value =
        if primary_key.is_a? Array
          _set_composite_primary_key_values primary_key, values
        else
          _set_single_primary_key_value primary_key, values
        end
      if ActiveRecord::VERSION::MAJOR >= 7
        im = Arel::InsertManager.new arel_table
        im.insert(values.transform_keys { |name| arel_table[name] })
      else
        im = arel_table.compile_insert _substitute_values(values)
      end
      connection.insert(im, "#{self} Create", primary_key || false, primary_key_value)
    end

    def self._upsert_record values
      _buffer_record values, :insert_or_update
    end

    def self.insert_all _attributes, _returning: nil, _unique_by: nil
      raise NotImplementedError, "Cloud Spanner does not support skip_duplicates."
    end

    def self.insert_all! attributes, returning: nil
      return super unless spanner_adapter?
      return super if active_transaction? && !buffered_mutations?

      # This might seem inefficient, but is actually not, as it is only buffering a mutation locally.
      # The mutations will be sent as one batch when the transaction is committed.
      if active_transaction?
        attributes.each do |record|
          _insert_record record
        end
      else
        transaction isolation: :buffered_mutations do
          attributes.each do |record|
            _insert_record record
          end
        end
      end
    end

    def self.upsert_all attributes, returning: nil, unique_by: nil
      return super unless spanner_adapter?
      if active_transaction? && !buffered_mutations?
        raise NotImplementedError, "Cloud Spanner does not support upsert using DML. " \
                                   "Use upsert outside a transaction block or in a transaction " \
                                   "block with isolation: :buffered_mutations"
      end

      # This might seem inefficient, but is actually not, as it is only buffering a mutation locally.
      # The mutations will be sent as one batch when the transaction is committed.
      if active_transaction?
        attributes.each do |record|
          _upsert_record record
        end
      else
        transaction isolation: :buffered_mutations do
          attributes.each do |record|
            _upsert_record record
          end
        end
      end
    end

    def self._buffer_record values, method
      primary_key_value =
        if primary_key.is_a? Array
          _set_composite_primary_key_values primary_key, values
        else
          _set_single_primary_key_value primary_key, values
        end

      metadata = TableMetadata.new self, arel_table
      columns, grpc_values = _create_grpc_values_for_insert metadata, values

      write = Google::Cloud::Spanner::V1::Mutation::Write.new(
        table: arel_table.name,
        columns: columns,
        values: [grpc_values.list_value]
      )
      mutation = Google::Cloud::Spanner::V1::Mutation.new(
        "#{method}": write
      )

      connection.current_spanner_transaction.buffer mutation

      primary_key_value
    end

    def self._set_composite_primary_key_values primary_key, values
      primary_key_value = []
      primary_key.each do |col|
        value = values[col]

        if !value && prefetch_primary_key?
          value =
            if ActiveRecord::VERSION::MAJOR >= 7
              ActiveModel::Attribute.from_database col, next_sequence_value, ActiveModel::Type::BigInteger.new
            else
              next_sequence_value
            end
          values[col] = value
        end
        if value.is_a? ActiveModel::Attribute
          value = value.value
        end
        primary_key_value.append value
      end
      primary_key_value
    end

    def self._set_single_primary_key_value primary_key, values
      primary_key_value = values[primary_key] || values[primary_key.to_sym]

      if !primary_key_value && prefetch_primary_key?
        primary_key_value = next_sequence_value
        if ActiveRecord::VERSION::MAJOR >= 7
          values[primary_key] = ActiveModel::Attribute.from_database primary_key, primary_key_value,
                                                                     ActiveModel::Type::BigInteger.new
        else
          values[primary_key] = primary_key_value
        end
      end
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

    def _execute_version_check attempted_action # rubocop:disable Metrics/AbcSize
      locking_column = self.class.locking_column
      previous_lock_value = read_attribute_before_type_cast locking_column

      primary_key = self.class.primary_key
      if primary_key.is_a? Array
        pk_sql = ""
        params = {}
        param_types = {}
        id = id_in_database
        primary_key.each_with_index do |col, idx|
          pk_sql.concat "`#{col}`=@id#{idx}"
          pk_sql.concat " AND " if idx < primary_key.length - 1

          params["id#{idx}"] = id[idx]
          param_types["id#{idx}"] = :INT64
        end
        params["lock_version"] = previous_lock_value
        param_types["lock_version"] = :INT64
      else
        pk_sql = "`#{self.class.primary_key}` = @id"
        params = { "id" => id_in_database, "lock_version" => previous_lock_value }
        param_types = { "id" => :INT64, "lock_version" => :INT64 }
      end

      # We need to check the version using a SELECT query, as a mutation cannot include a WHERE clause.
      sql = "SELECT 1 FROM `#{self.class.arel_table.name}` " \
              "WHERE #{pk_sql} AND `#{locking_column}` = @lock_version"
      locked_row = self.class.connection.raw_connection.execute_query sql, params: params, types: param_types
      raise ActiveRecord::StaleObjectError.new(self, attempted_action) unless locked_row.rows.any?
    end
  end
end
