# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "io/console"
require_relative "../config/environment"
require_relative "models/entity_with_array_types"

class Application
  def self.run # rubocop:disable Metrics/AbcSize
    # Create a record with all array types.
    record = EntityWithArrayTypes.create \
      col_array_string: ["value1", "value2", "value3"],
      col_array_int64: [100, 200, 300],
      col_array_float64: [3.14, 2.0 / 3.0],
      col_array_numeric: [6.626, 3.20],
      # All arrays can contain null elements.
      col_array_bool: [true, false, nil, true],
      col_array_bytes: [StringIO.new("value1"), StringIO.new("value2")],
      col_array_date: [::Date.new(2021, 6, 23), ::Date.new(2021, 6, 28)],
      # Timestamps can be specified in any timezone, but Cloud Spanner will always convert and store them in UTC.
      col_array_timestamp: [::Time.new(2021, 6, 23, 17, 8, 21, "+02:00"), ::Time.utc(2021, 6, 23, 17, 8, 21)]

    # Reload the record from Cloud Spanner and print out the values.
    record = record.reload
    puts ""
    puts "Saved record #{record.id} with array values: "
    puts "String array: #{record.col_array_string}"
    puts "Int64 array: #{record.col_array_int64}"
    puts "Float64 array: #{record.col_array_float64}"
    puts "Numeric array: #{record.col_array_numeric}"
    puts "Bool array: #{record.col_array_bool}"
    puts "Bytes array: #{record.col_array_bytes.map(&:read)}"
    puts "Date array: #{record.col_array_date}"
    puts "Timestamp array: #{record.col_array_timestamp}"

    puts ""
    puts "Press any key to end the application"
    $stdin.getch
  end
end

Application.run
