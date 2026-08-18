# Copyright 2026 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "test_helper"
require "delegate"

class SpannerActiveRecordConverterTest < Minitest::Test
  Converter = ActiveRecord::Type::Spanner::SpannerActiveRecordConverter

  class CustomInteger < ActiveModel::Type::Integer
  end

  class CustomString < ActiveModel::Type::String
  end

  class TypeDecorator < SimpleDelegator
  end

  def test_convert_active_model_type_to_spanner_standard_types
    expected_mappings = {
      ActiveModel::Type::Integer.new => :INT64,
      ActiveModel::Type::BigInteger.new => :INT64,
      ActiveModel::Type::Boolean.new => :BOOL,
      ActiveModel::Type::String.new => :STRING,
      ActiveModel::Type::ImmutableString.new => :STRING,
      ActiveModel::Type::Binary.new => :BYTES,
      ActiveRecord::Type::Spanner::Bytes.new => :BYTES,
      ActiveModel::Type::Float.new => :FLOAT64,
      ActiveModel::Type::Decimal.new => :NUMERIC,
      ActiveModel::Type::DateTime.new => :TIMESTAMP,
      ActiveModel::Type::Time.new => :TIMESTAMP,
      ActiveRecord::Type::Spanner::Time.new => :TIMESTAMP,
      ActiveModel::Type::Date.new => :DATE,
      ActiveRecord::Type::Json.new => :JSON,
      ActiveRecord::Type::Spanner::Uuid.new => :UUID
    }

    expected_mappings.each do |type, expected_code|
      assert_equal expected_code, Converter.convert_active_model_type_to_spanner(type)
    end
  end

  def test_convert_active_model_type_to_spanner_nil
    assert_nil Converter.convert_active_model_type_to_spanner(nil)
  end

  def test_convert_active_model_type_to_spanner_unrecognized_type
    assert_nil Converter.convert_active_model_type_to_spanner(Object.new)
  end

  def test_convert_active_model_type_to_spanner_array
    int_array = ActiveRecord::Type::Spanner::Array.new ActiveModel::Type::Integer.new
    assert_equal [:INT64], Converter.convert_active_model_type_to_spanner(int_array)

    string_array = ActiveRecord::Type::Spanner::Array.new ActiveModel::Type::String.new
    assert_equal [:STRING], Converter.convert_active_model_type_to_spanner(string_array)
  end

  def test_convert_active_model_type_to_spanner_delegator
    decorated = TypeDecorator.new ActiveModel::Type::Integer.new
    assert_equal :INT64, Converter.convert_active_model_type_to_spanner(decorated)
  end

  class CustomArray < ActiveRecord::Type::Spanner::Array
  end

  def test_convert_active_model_type_to_spanner_custom_subclasses
    assert_equal :INT64, Converter.convert_active_model_type_to_spanner(CustomInteger.new)
    assert_equal :STRING, Converter.convert_active_model_type_to_spanner(CustomString.new)
    custom_array = CustomArray.new ActiveModel::Type::Integer.new
    assert_equal [:INT64], Converter.convert_active_model_type_to_spanner(custom_array)
  end

  def test_serialize_with_transaction_isolation_level
    int_type = ActiveModel::Type::Integer.new
    assert_equal 42, Converter.serialize_with_transaction_isolation_level(int_type, "42", :dml)
    assert_equal "hello", Converter.serialize_with_transaction_isolation_level(nil, "hello", :dml)
  end
end
