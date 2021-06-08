# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "base64"
require "securerandom"

class StatementResult
  QUERY = 1
  UPDATE_COUNT = 2
  EXCEPTION = 3

  def self.create_select1_result
    create_single_int_result_set "Col1", 1
  end

  def self.create_single_int_result_set col_name, value
    col1 = Google::Cloud::Spanner::V1::StructType::Field.new name: col_name, type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::INT64)
    metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new
    metadata.row_type = Google::Cloud::Spanner::V1::StructType.new
    metadata.row_type.fields << col1
    resultSet = Google::Cloud::Spanner::V1::ResultSet.new
    resultSet.metadata = metadata
    row = Google::Protobuf::ListValue.new
    row.values << Google::Protobuf::Value.new(string_value: value.to_s)
    resultSet.rows << row

    StatementResult.new(resultSet)
  end

  def self.create_random_result row_count
    col_bool = Google::Cloud::Spanner::V1::StructType::Field.new name: "ColBool", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::BOOL)
    col_int64 = Google::Cloud::Spanner::V1::StructType::Field.new name: "ColInt64", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::INT64)
    col_float64 = Google::Cloud::Spanner::V1::StructType::Field.new name: "ColFloat64", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::FLOAT64)
    col_numeric = Google::Cloud::Spanner::V1::StructType::Field.new name: "ColNumeric", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::NUMERIC)
    col_string = Google::Cloud::Spanner::V1::StructType::Field.new name: "ColString", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::STRING)
    col_bytes = Google::Cloud::Spanner::V1::StructType::Field.new name: "ColBytes", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::BYTES)
    col_date = Google::Cloud::Spanner::V1::StructType::Field.new name: "ColDate", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::DATE)
    col_timestamp = Google::Cloud::Spanner::V1::StructType::Field.new name: "ColTimestamp", type: Google::Cloud::Spanner::V1::Type.new(code: Google::Cloud::Spanner::V1::TypeCode::TIMESTAMP)

    metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new row_type: Google::Cloud::Spanner::V1::StructType.new
    metadata.row_type.fields.push(col_bool, col_int64, col_float64, col_numeric, col_string, col_bytes, col_date,
                                  col_timestamp)
    result_set = Google::Cloud::Spanner::V1::ResultSet.new metadata: metadata

    (1..row_count).each { |i|
      row = Google::Protobuf::ListValue.new
      row.values.push(
        random_value_or_null(Google::Protobuf::Value.new(bool_value: [true, false].sample), 10),
        random_value_or_null(Google::Protobuf::Value.new(string_value: SecureRandom.random_number(1000000).to_s), 10),
        random_value_or_null(Google::Protobuf::Value.new(number_value: SecureRandom.random_number), 10),
        random_value_or_null(Google::Protobuf::Value.new(string_value: SecureRandom.random_number(999999.99).round(2).to_s), 10),
        random_value_or_null(Google::Protobuf::Value.new(string_value: SecureRandom.alphanumeric(SecureRandom.random_number(10..200))), 10),
        random_value_or_null(Google::Protobuf::Value.new(string_value: Base64.encode64(SecureRandom.alphanumeric(SecureRandom.random_number(10..200)))), 10),
        random_value_or_null(Google::Protobuf::Value.new(string_value: sprintf("%04d-%02d-%02d",
                                                  SecureRandom.random_number(1900..2021),
                                                  SecureRandom.random_number(1..12),
                                                  SecureRandom.random_number(1..28))
        ), 10),
        random_value_or_null(Google::Protobuf::Value.new(string_value: random_timestamp_string),10)
      )
      result_set.rows.push row
    }

    StatementResult.new result_set
  end

  def self.random_timestamp_string
    sprintf("%04d-%02d-%02dT%02d:%02d:%02d.%dZ",
            SecureRandom.random_number(1900..2021),
            SecureRandom.random_number(1..12),
            SecureRandom.random_number(1..28),
            SecureRandom.random_number(0..23),
            SecureRandom.random_number(0..59),
            SecureRandom.random_number(0..59),
            SecureRandom.random_number(1..999999999))
  end

  def self.random_value_or_null value, null_fraction_divisor
    SecureRandom.random_number(1..null_fraction_divisor) == 1 ?
      Google::Protobuf::Value.new(null_value: "NULL_VALUE")
      : value
  end

  attr_reader :result_type
  attr_reader :result

  def initialize result
    if result.is_a?(Google::Cloud::Spanner::V1::ResultSet)
      @result_type = QUERY
      @result = result
    elsif result.is_a?(Integer)
      @result_type = UPDATE_COUNT
      @result = create_update_count_result result
    elsif result.is_a?(Exception)
      @result_type = EXCEPTION
      @result = result
    else
      raise ArgumentError, "result must be either a ResultSet, an Integer (update count) or an exception"
    end
  end

  def each
    return enum_for(:each) unless block_given?
    if @result.rows.length == 0
      partial = Google::Cloud::Spanner::V1::PartialResultSet.new
      partial.metadata = result.metadata
      partial.stats = result.stats
      yield partial
    else
      @result.rows.each do |row|
        index = 0
        partial = Google::Cloud::Spanner::V1::PartialResultSet.new
        if index == 0
          partial.metadata = result.metadata
        end
        index += 1
        if index == result.rows.length
          partial.stats = result.stats
        end
        partial.values = row.values
        yield partial
      end
    end
  end

  private

  def create_update_count_result update_count
    resultSet = Google::Cloud::Spanner::V1::ResultSet.new
    metadata = Google::Cloud::Spanner::V1::ResultSetMetadata.new
    metadata.row_type = Google::Cloud::Spanner::V1::StructType.new
    resultSet.metadata = metadata
    resultSet.stats = Google::Cloud::Spanner::V1::ResultSetStats.new
    resultSet.stats.row_count_exact = update_count

    resultSet
  end

end
