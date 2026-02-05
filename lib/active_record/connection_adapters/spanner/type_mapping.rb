# Copyright 2026 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# frozen_string_literal: true

NATIVE_DATABASE_TYPES = {
  primary_key:  "INT64",
  parent_key:   "INT64",
  string:       { name: "STRING", limit: "MAX" },
  text:         { name: "STRING", limit: "MAX" },
  integer:      { name: "INT64" },
  bigint:       { name: "INT64" },
  float:        { name: "FLOAT64" },
  decimal:      { name: "NUMERIC" },
  numeric:      { name: "NUMERIC" },
  datetime:     { name: "TIMESTAMP" },
  time:         { name: "TIMESTAMP" },
  date:         { name: "DATE" },
  binary:       { name: "BYTES", limit: "MAX" },
  boolean:      { name: "BOOL" },
  json:         { name: "JSON" }
}.freeze
