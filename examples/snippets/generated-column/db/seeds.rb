# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require_relative "../../config/environment.rb"
require_relative "../models/singer"

first_names = %w[Pete Alice John Ethel Trudy Naomi Wendy Ruben Thomas Elly]
last_names = %w[Wendelson Allison Peterson Johnson Henderson Ericsson Aronson Tennet Courtou]

# This ensures all the records are inserted using one read/write transaction that will use mutations instead of DML.
ActiveRecord::Base.transaction isolation: :buffered_mutations do
  10.times do
    Singer.create first_name: first_names.sample, last_name: last_names.sample
  end
end
