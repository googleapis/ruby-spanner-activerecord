# SPDX-License-Identifier: MIT

require_relative "../test_helper"
require "open3"

class SpannerJsonTest < Minitest::Test
  def setup
    @encoder = ActiveRecordSpannerAdapter::JsonEncoder.new
    @type = ActiveRecord::Type::Spanner::Json.new
  end

  def test_uses_nlohmann_float_tokens
    {
      0.0023529 => "0.0023528999999999998",
      1.240425 => "1.240425",
      -0.0 => "-0.0",
      1.0e-7 => "1e-07",
      Float::MIN => "2.2250738585072014e-308",
      Float::MAX => "1.7976931348623157e+308"
    }.each do |value, expected|
      assert_equal expected, ActiveRecordSpannerAdapter::FloatFormatter.serialize_float(value)
      assert_equal expected, @encoder.encode(value)
      assert_equal expected, @type.serialize(value)
    end
  end

  def test_preserves_binary_float_values
    random = Random.new(42)
    500.times do
      bytes = random.bytes(8)
      value = bytes.unpack1("G")
      next unless value.finite?

      serialized = @encoder.encode(value)
      assert_equal bytes, [JSON.parse(serialized)].pack("G"), serialized
    end
  end

  def test_float_formatter_rejects_unsupported_values
    [Float::NAN, Float::INFINITY, -Float::INFINITY].each do |value|
      assert_raises(ArgumentError) { ActiveRecordSpannerAdapter::FloatFormatter.serialize_float(value) }
    end
    assert_raises(TypeError) { ActiveRecordSpannerAdapter::FloatFormatter.serialize_float(1) }
    assert_raises(TypeError) { ActiveRecordSpannerAdapter::FloatFormatter.serialize_float("1.25") }
  end

  def test_encodes_nested_values_without_mutating_them
    value = { amount: 0.0023529, nested: [1.240425, { amount: -0.0 }], nil: nil }
    original = Marshal.load(Marshal.dump(value))

    assert_equal '{"amount":0.0023528999999999998,"nested":[1.240425,{"amount":-0.0}],"nil":null}',
                 @type.serialize(value)
    assert_equal original, value
    assert_equal 0.0023529, value[:amount]
  end

  def test_preserves_rails_json_semantics
    value = {
      decimal: BigDecimal("1.23"),
      date: Date.new(2026, 9, 28),
      time: Time.utc(2026, 9, 28, 12, 34, 56),
      text: "<script>&\u2028\u2029",
      values: [true, false, nil, Float::NAN, Float::INFINITY, -Float::INFINITY]
    }

    assert_equal ActiveSupport::JSON.encode(value), @encoder.encode(value)
    assert_equal ActiveRecord::Type::Json.new.serialize(value), @type.serialize(value)
  end

  def test_preserves_as_json_and_encoder_options
    value = Class.new do
      def as_json(options = nil)
        { amount: 0.0023529, omitted: true }.as_json(options)
      end
    end.new

    encoder = ActiveRecordSpannerAdapter::JsonEncoder.new(only: :amount)
    assert_equal '{"amount":0.0023528999999999998}', encoder.encode(value)
  end

  def test_preserves_scalar_json_and_sql_null
    assert_nil @type.serialize(nil)
    assert_equal "null", @encoder.encode(nil)
    assert_equal "false", @type.serialize(false)
    assert_equal "42", @type.serialize(42)
    assert_equal '"already a string"', @type.serialize("already a string")
    assert_nil @type.deserialize(nil)
    assert_equal({ "amount" => 1.240425 }, @type.deserialize('{"amount":1.240425}'))
  end

  def test_does_not_replace_global_float_or_json_encoding
    script = <<~RUBY
      gem "json", #{JSON::VERSION.inspect}
      gem "activesupport", #{ActiveSupport::VERSION::STRING.inspect}
      gem "activerecord", #{ActiveRecord::VERSION::STRING.inspect}
      require "logger"
      require "active_record"
      require "active_support/core_ext/numeric"
      value = { amounts: [1.240425, 0.0023529, 1.0e-7, -0.0], text: "<>&" }
      original_float_to_s = Float.instance_method(:to_s)
      original_float_strings = value[:amounts].map(&:to_s)
      original_encoder = ActiveSupport::JSON::Encoding.json_encoder
      original_json = JSON.generate(value)
      original_active_support_json = ActiveSupport::JSON.encode(value)
      original_record_json = ActiveRecord::Type::Json.new.serialize(value)

      require "activerecord-spanner-adapter"
      require "active_record/connection_adapters/spanner_adapter"

      abort "Float#to_s changed" unless Float.instance_method(:to_s) == original_float_to_s
      abort "Float formatting changed" unless value[:amounts].map(&:to_s) == original_float_strings
      abort "global JSON encoder changed" unless ActiveSupport::JSON::Encoding.json_encoder == original_encoder
      abort "JSON.generate changed" unless JSON.generate(value) == original_json
      abort "ActiveSupport JSON changed" unless ActiveSupport::JSON.encode(value) == original_active_support_json
      abort "ActiveRecord JSON changed" unless ActiveRecord::Type::Json.new.serialize(value) == original_record_json
    RUBY
    output, status = Open3.capture2e(RbConfig.ruby, "-I", $LOAD_PATH.join(File::PATH_SEPARATOR), "-e", script)

    assert status.success?, output
  end

  def test_type_map_uses_spanner_json_for_json_and_json_arrays
    type_map = ActiveRecord::ConnectionAdapters::SpannerAdapter::TYPE_MAP
    assert_instance_of ActiveRecord::Type::Spanner::Json, type_map.lookup("JSON")
    array_type = type_map.lookup("ARRAY<JSON>")
    assert_instance_of ActiveRecord::Type::Spanner::Json, array_type.element_type
    assert_equal ['{"amount":0.0023528999999999998}', nil, "1.240425"],
                 array_type.serialize([{ amount: 0.0023529 }, nil, 1.240425])
    assert_instance_of ActiveRecord::Type::Spanner::Json, ActiveRecord::Type.lookup(:json, adapter: :spanner)
  end
end

class SpannerSdkJsonTest < Minitest::Test
  def test_root_gem_require_enables_sdk_json_without_patching_global_serialization
    script = <<~RUBY
      gem "json", #{JSON::VERSION.inspect}
      gem "activesupport", #{ActiveSupport::VERSION::STRING.inspect}
      gem "activerecord", #{ActiveRecord::VERSION::STRING.inspect}
      require "json"
      original_json = JSON.generate(1.240425)
      original_float_to_s = Float.instance_method(:to_s)
      require "activerecord-spanner-adapter"
      value = Google::Cloud::Spanner::Convert.object_to_grpc_value({ amount: 1.240425 }, :JSON)
      abort "incorrect JSON token" unless value.string_value == '{"amount":1.240425}'
      abort "global JSON changed" unless JSON.generate(1.240425) == original_json
      abort "Float#to_s changed" unless Float.instance_method(:to_s) == original_float_to_s
    RUBY
    output, status = Open3.capture2e(RbConfig.ruby, "-I", $LOAD_PATH.join(File::PATH_SEPARATOR), "-e", script)

    assert status.success?, output
  end

  def test_serializes_json_query_parameters_and_json_arrays
    params = Google::Cloud::Spanner::Convert.to_query_params(
      { json: { amount: 0.0023529 }, array: [{ amount: 1.240425 }, nil] },
      { json: :JSON, array: [:JSON] }
    )

    value, type = params.fetch("json")
    assert_equal '{"amount":0.0023528999999999998}', value.string_value
    assert_equal :JSON, type.code
    value, type = params.fetch("array")
    assert_equal '{"amount":1.240425}', value.list_value.values[0].string_value
    assert_equal :null_value, value.list_value.values[1].kind
    assert_equal :ARRAY, type.code
    assert_equal :JSON, type.array_element_type.code
  end

  def test_serializes_json_hashes_in_direct_sdk_mutations
    commit = Google::Cloud::Spanner::Commit.new
    commit.insert "events", id: 1, data: { amount: 0.0023529 }, data_array: [{ amount: 1.240425 }, nil]
    mutation = commit.mutations.first.insert
    values = mutation.columns.zip(mutation.values.first.values).to_h

    assert_equal '{"amount":0.0023528999999999998}', values.fetch("data").string_value
    assert_equal '{"amount":1.240425}', values.fetch("data_array").list_value.values[0].string_value
    assert_equal :null_value, values.fetch("data_array").list_value.values[1].kind
  end

  def test_preserves_struct_parameters_and_float64_values
    fields = Google::Cloud::Spanner::Fields.new(amount: :FLOAT64, json: :JSON)
    value, type = Google::Cloud::Spanner::Convert.object_to_grpc_value_and_type(
      { amount: 0.0023529, json: { amount: 1.240425 } }, fields
    )

    assert_equal :STRUCT, type.code
    assert_equal :number_value, value.list_value.values[0].kind
    assert_equal 0.0023529, value.list_value.values[0].number_value
    assert_equal '{"amount":1.240425}', value.list_value.values[1].string_value

    value, type = Google::Cloud::Spanner::Convert.object_to_grpc_value_and_type(0.0023529)
    assert_equal :FLOAT64, type.code
    assert_equal :number_value, value.kind
    assert_equal 0.0023529, value.number_value
  end

  def test_preserves_inferred_structs_and_preencoded_json
    value, type = Google::Cloud::Spanner::Convert.object_to_grpc_value_and_type({ amount: 0.0023529 })
    assert_equal :STRUCT, type.code
    assert_equal 0.0023529, value.list_value.values[0].number_value

    json = '{"amount": 0.0023529}'
    value, type = Google::Cloud::Spanner::Convert.object_to_grpc_value_and_type(json, :JSON)
    assert_equal :JSON, type.code
    assert_equal json, value.string_value
  end

  def test_preserves_custom_sdk_conversion_hooks
    column_value = Class.new(Hash) do
      def to_column_value
        "custom column value"
      end
    end.new
    grpc_value = Class.new(Hash) do
      def to_grpc_value_and_type
        [Google::Protobuf::Value.new(string_value: "custom grpc value"),
         Google::Cloud::Spanner::V1::Type.new(code: :JSON)]
      end
    end.new

    assert_equal "custom column value",
                 Google::Cloud::Spanner::Convert.object_to_grpc_value(column_value, :JSON).string_value
    assert_equal "custom grpc value",
                 Google::Cloud::Spanner::Convert.object_to_grpc_value(grpc_value, :JSON).string_value
  end
end
