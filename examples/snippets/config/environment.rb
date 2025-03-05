# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "logger" # https://github.com/rails/rails/issues/54260
require "active_record"
require "bundler"

Dir["../../lib/*.rb"].each { |file| require file }

if ActiveRecord.version >= Gem::Version.create("7.2.0")
  ActiveRecord::ConnectionAdapters.register "spanner", "ActiveRecord::ConnectionAdapters::SpannerAdapter"
end

Bundler.require

ActiveRecord::Base.establish_connection(
  adapter: "spanner",
  emulator_host: "localhost:9010",
  project: "test-project",
  instance: "test-instance",
  database: "testdb",
  default_sequence_kind: "BIT_REVERSED_POSITIVE"
)
ActiveRecord::Base.logger = nil
