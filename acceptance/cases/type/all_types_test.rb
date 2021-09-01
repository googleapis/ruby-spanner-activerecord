# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"
require "models/all_types"

module ActiveRecord
  module Type
    class AllTypesTest < SpannerAdapter::TestCase
      include SpannerAdapter::Associations::TestHelper

      # Runs the given block in a transaction with the given isolation level, or without a transaction if isolation is
      # nil.
      def run_in_transaction isolation
        if isolation
          Base.transaction isolation: isolation do
            yield
          end
        else
          yield
        end
      end

      def create_test_record
        AllTypes.create col_string: "string", col_int64: 100, col_float64: 3.14, col_numeric: 6.626, col_bool: true,
          col_bytes: StringIO.new("bytes"), col_date: ::Date.new(2021, 6, 23),
          col_timestamp: ::Time.new(2021, 6, 23, 17, 8, 21, "+02:00"),
          col_json: ENV["SPANNER_EMULATOR_HOST"] ? "" : { kind: "user_renamed", change: %w[jack john]},
          col_array_string: ["string1", nil, "string2"],
          col_array_int64: [100, nil, 200],
          col_array_float64: [3.14, nil, 2.0/3.0],
          col_array_numeric: [6.626, nil, 3.20],
          col_array_bool: [true, nil, false],
          col_array_bytes: [StringIO.new("bytes1"), nil, StringIO.new("bytes2")],
          col_array_date: [::Date.new(2021, 6, 23), nil, ::Date.new(2021, 6, 24)],
          col_array_timestamp: [::Time.new(2021, 6, 23, 17, 8, 21, "+02:00"), nil, \
                                ::Time.new(2021, 6, 24, 17, 8, 21, "+02:00")],
          col_array_json: ENV["SPANNER_EMULATOR_HOST"] ? [""] : \
                            [{ kind: "user_renamed", change: %w[jack john]}, nil, \
                             { kind: "user_renamed", change: %w[alice meredith]}]
      end

      def test_create_record
        [nil, :serializable, :buffered_mutations].each do |isolation|
          initial_count = AllTypes.count
          record = nil
          run_in_transaction isolation do
            record = create_test_record
          end

          # Verify that the record was created and that the data can be read back.
          assert_equal initial_count + 1, AllTypes.count

          record = AllTypes.find record.id
          assert_equal "string", record.col_string
          assert_equal 100, record.col_int64
          assert_equal 3.14, record.col_float64
          assert_equal 6.626, record.col_numeric
          assert_equal true, record.col_bool
          assert_equal StringIO.new("bytes").read, record.col_bytes.read
          assert_equal ::Date.new(2021, 6, 23), record.col_date
          assert_equal ::Time.new(2021, 6, 23, 17, 8, 21, "+02:00").utc, record.col_timestamp.utc
          assert_equal ({"kind" => "user_renamed", "change" => %w[jack john]}),
                       record.col_json unless ENV["SPANNER_EMULATOR_HOST"]

          assert_equal ["string1", nil, "string2"], record.col_array_string
          assert_equal [100, nil, 200], record.col_array_int64
          assert_equal [3.14, nil, 2.0/3.0], record.col_array_float64
          assert_equal [6.626, nil, 3.20], record.col_array_numeric
          assert_equal [true, nil, false], record.col_array_bool
          assert_equal [StringIO.new("bytes1"), nil, StringIO.new("bytes2")].map { |bytes| bytes&.read },
                       record.col_array_bytes.map { |bytes| bytes&.read }
          assert_equal [::Date.new(2021, 6, 23), nil, ::Date.new(2021, 6, 24)], record.col_array_date
          assert_equal [::Time.new(2021, 6, 23, 17, 8, 21, "+02:00"), \
                            nil, \
                            ::Time.new(2021, 6, 24, 17, 8, 21, "+02:00")].map { |timestamp| timestamp&.utc },
                       record.col_array_timestamp.map { |timestamp| timestamp&.utc}
          assert_equal [{"kind" => "user_renamed", "change" => %w[jack john]}, \
                        nil, \
                        {"kind" => "user_renamed", "change" => %w[alice meredith]}],
                       record.col_array_json unless ENV["SPANNER_EMULATOR_HOST"]
        end
      end

      def test_update_record
        [nil, :serializable, :buffered_mutations].each do |isolation|
          # First create a test record outside a transaction.
          record = create_test_record

          run_in_transaction isolation do
            # Update the record in a transaction using different isolation levels.
            record.update col_string: "new string", col_int64: 200, col_float64: 6.28, col_numeric: 10.1,
                          col_bool: false, col_bytes: StringIO.new("new bytes"),
                          col_date: ::Date.new(2021, 6, 28),
                          col_timestamp: ::Time.new(2021, 6, 28, 11, 22, 21, "+02:00"),
                          col_json: ENV["SPANNER_EMULATOR_HOST"] ? "" : { kind: "user_created", change: %w[jack alice]},
                          col_array_string: ["new string 1", "new string 2"],
                          col_array_int64: [300, 200, 100],
                          col_array_float64: [1.1, 2.2, 3.3],
                          col_array_numeric: [3.3, 2.2, 1.1],
                          col_array_bool: [false, true, false],
                          col_array_bytes: [StringIO.new("new bytes 1"), StringIO.new("new bytes 2")],
                          col_array_date: [::Date.new(2021, 6, 28)],
                          col_array_timestamp: [::Time.utc(2020, 12, 31, 0, 0, 0)],
                          col_array_json: ENV["SPANNER_EMULATOR_HOST"] ?
                                            [""] : \
                                            [{ kind: "user_created", change: %w[jack alice]}]
          end

          # Verify that the record was updated.
          record = AllTypes.find record.id
          assert_equal "new string", record.col_string
          assert_equal 200, record.col_int64
          assert_equal 6.28, record.col_float64
          assert_equal 10.1, record.col_numeric
          assert_equal false, record.col_bool
          assert_equal StringIO.new("new bytes").read, record.col_bytes.read
          assert_equal ::Date.new(2021, 6, 28), record.col_date
          assert_equal ::Time.new(2021, 6, 28, 11, 22, 21, "+02:00").utc, record.col_timestamp.utc
          assert_equal ({"kind" => "user_created", "change" => %w[jack alice]}),
                       record.col_json unless ENV["SPANNER_EMULATOR_HOST"]

          assert_equal ["new string 1", "new string 2"], record.col_array_string
          assert_equal [300, 200, 100], record.col_array_int64
          assert_equal [1.1, 2.2, 3.3], record.col_array_float64
          assert_equal [3.3, 2.2, 1.1], record.col_array_numeric
          assert_equal [false, true, false], record.col_array_bool
          assert_equal [StringIO.new("new bytes 1"), StringIO.new("new bytes 2")].map(&:read),
                       record.col_array_bytes.map(&:read)
          assert_equal [::Date.new(2021, 6, 28)], record.col_array_date
          assert_equal [::Time.utc(2020, 12, 31, 0, 0, 0)], record.col_array_timestamp.map(&:utc)
          assert_equal [{"kind" => "user_created", "change" => %w[jack alice]}],
                       record.col_array_json unless ENV["SPANNER_EMULATOR_HOST"]
        end
      end

      def test_create_empty_arrays
        [nil, :serializable, :buffered_mutations].each do |isolation|
          record = nil
          run_in_transaction isolation do
            record = AllTypes.create \
              col_array_string: [],
              col_array_int64: [],
              col_array_float64: [],
              col_array_numeric: [],
              col_array_bool: [],
              col_array_bytes: [],
              col_array_date: [],
              col_array_timestamp: [],
              col_array_json: []
          end

          record = AllTypes.find record.id
          assert_equal [], record.col_array_string
          assert_equal [], record.col_array_int64
          assert_equal [], record.col_array_float64
          assert_equal [], record.col_array_numeric
          assert_equal [], record.col_array_bool
          assert_equal [], record.col_array_bytes
          assert_equal [], record.col_array_date
          assert_equal [], record.col_array_timestamp
          assert_equal [], record.col_array_json
        end
      end
    end
  end
end
