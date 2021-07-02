# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
require_relative "../../config/environment.rb"
require_relative "../models/singer"

first_names = %w[Nelson Todd William Alex Dominique Adenoid Steve Nathan Beverly Annie Amy Norma Diana Regan Phyllis]
last_names = %w[Thornton Morgan Lawson Collins Frost Maxwell Sanders Fleming Jones Webb Walker French Montgomery Quinn]

30.times do
  Singer.create first_name: first_names.sample, last_name: last_names.sample,
                birth_date: Date.new(rand(1920...2010), rand(1...12), rand(1...28))
end
