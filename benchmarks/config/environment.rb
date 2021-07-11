# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "active_record"
require "bundler"

Dir["../lib/*.rb"].each { |file| require file }

Bundler.require
