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

      def test_create_record
        [nil, :serializable, :buffered_mutations].each do |isolation|
          initial_count = AllTypes.count
          record = nil
          run_in_transaction isolation do
            record = AllTypes.create col_string: "string", col_int64: 100, col_float64: 3.14, col_numeric: 6.626, col_bool: true,
                            col_bytes: StringIO.new("bytes"), col_date: ::Date.new(2021, 6, 23),
                            col_timestamp: ::Time.new(2021, 6, 23, 17, 8, 21, "+02:00"),
                            col_array_string: ["string1", nil, "string2"],
                            col_array_int64: [100, nil, 200],
                            col_array_float64: [3.14, nil, 2.0/3.0],
                            col_array_numeric: [6.626, nil, 3.20],
                            col_array_bool: [true, nil, false],
                            col_array_bytes: [StringIO.new("bytes1"), nil, StringIO.new("bytes2")],
                            col_array_date: [::Date.new(2021, 6, 23), nil, ::Date.new(2021, 6, 24)],
                            col_array_timestamp: [::Time.new(2021, 6, 23, 17, 8, 21, "+02:00"), nil, \
                                          ::Time.new(2021, 6, 24, 17, 8, 21, "+02:00")]
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
        end
      end
    end
  end
end
