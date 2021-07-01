# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

class EntityWithArrayTypes < ActiveRecord::Base
  # This entity has one attribute for each possible ARRAY data type in Cloud Spanner.
  # col_array_string ARRAY<STRING(MAX)>
  # col_array_int64 ARRAY<INT64>
  # col_array_float64 ARRAY<FLOAT64>
  # col_array_numeric ARRAY<NUMERIC>
  # col_array_bool ARRAY<BOOL>
  # col_array_bytes ARRAY<BYTES(MAX)>
  # col_array_date ARRAY<DATE>
  # col_array_timestamp ARRAY<TIMESTAMP>
  #
end
