# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

module ActiveRecord
  class Base
    # Creates an object (or multiple objects) and saves it to the database. This method will use mutations instead
    # of DML if there is no active transaction, or if the active transaction has been created with the option
    # isolation: :buffered_mutations.
    def self.create attributes = nil, &block
      return super if active_transaction?

      transaction isolation: :buffered_mutations do
        return super
      end
    end

    # Deletes all records of this class. This method will use mutations instead of DML if there is no active
    # transaction, or if the active transaction has been created with the option isolation: :buffered_mutations.
    def self.delete_all
      return super if active_transaction?

      transaction isolation: :buffered_mutations do
        return super
      end
    end

    # Updates the given attributes of the object in the database. This method will use mutations instead
    # of DML if there is no active transaction, or if the active transaction has been created with the option
    # isolation: :buffered_mutations.
    def update attributes
      return super if Base.active_transaction?

      transaction isolation: :buffered_mutations do
        return super
      end
    end

    # Deletes the object in the database. This method will use mutations instead
    # of DML if there is no active transaction, or if the active transaction has been created with the option
    # isolation: :buffered_mutations.
    def destroy
      return super if Base.active_transaction?

      transaction isolation: :buffered_mutations do
        return super
      end
    end

    private

    def self._insert_record values
      return super unless Base.connection&.current_spanner_transaction&.isolation == :buffered_mutations

      primary_key = self.primary_key
      primary_key_value = nil

      if primary_key && Hash === values
        primary_key_value = values[primary_key]

        if !primary_key_value && prefetch_primary_key?
          primary_key_value = next_sequence_value
          values[primary_key] = primary_key_value
        end
      end

      metadata = TableMetadata.new(self, arel_table)
      serialized_values = []
      columns = []
      values.each_pair do |k, v|
        type = metadata.type(k)
        serialized_values << type.serialize(v)
        columns << metadata.arel_attribute(k).name
      end
      grpc_values = Google::Protobuf::Value.new list_value:
        Google::Protobuf::ListValue.new(
          values: serialized_values.map do |value|
            Google::Cloud::Spanner::Convert.object_to_grpc_value(value)
          end
        )

      mutation = Google::Cloud::Spanner::V1::Mutation.new(
        insert: Google::Cloud::Spanner::V1::Mutation::Write.new(
          table: arel_table.name,
          columns: columns,
          values: [grpc_values.list_value]
        )
      )
      Base.connection.current_spanner_transaction.buffer mutation

      primary_key_value
    end

    def _update_row(attribute_names, attempted_action = "update")
      return super unless Base.connection&.current_spanner_transaction&.isolation == :buffered_mutations

      metadata = TableMetadata.new(self.class, self.class.arel_table)
      values = attributes_with_values(attribute_names)
      constraints = { @primary_key => id_in_database }

      # Use both the where values + the values that are actually set.
      all_values = [constraints, values]
      all_serialized_values = []
      all_columns = []
      all_values.each do |h|
        h.each_pair do |k, v|
          type = metadata.type(k)
          all_serialized_values << type.serialize(v)
          all_columns << metadata.arel_attribute(k).name
        end
      end
      grpc_values = Google::Protobuf::Value.new list_value:
        Google::Protobuf::ListValue.new(
          values: all_serialized_values.map do |value|
            Google::Cloud::Spanner::Convert.object_to_grpc_value(value)
          end
        )

      mutation = Google::Cloud::Spanner::V1::Mutation.new(
        update: Google::Cloud::Spanner::V1::Mutation::Write.new(
          table: self.class.arel_table.name,
          columns: all_columns,
          values: [grpc_values.list_value]
        )
      )
      Base.connection.current_spanner_transaction.buffer mutation
      1 # Affected rows
    end

    def _delete_row
      return super unless Base.connection&.current_spanner_transaction&.isolation == :buffered_mutations

      metadata = TableMetadata.new(self.class, self.class.arel_table)
      type = metadata.type(@primary_key)
      list_value = Google::Protobuf::ListValue.new(
        values: [Google::Cloud::Spanner::Convert.object_to_grpc_value(type.serialize(id_in_database))]
      )
      mutation = Google::Cloud::Spanner::V1::Mutation.new(
        delete: Google::Cloud::Spanner::V1::Mutation::Delete.new(
          table: self.class.arel_table.name,
          key_set: {keys: [list_value]}
        )
      )
      Base.connection.current_spanner_transaction.buffer mutation
      1 # Affected rows
    end

    def self.active_transaction?
      current_transaction = connection.current_transaction
      !(current_transaction.nil? || current_transaction.is_a?(ConnectionAdapters::NullTransaction))
    end
  end
end
