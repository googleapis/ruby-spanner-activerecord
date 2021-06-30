# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

module ActiveRecord
  module Type
    module Spanner
      class Array < Type::Value
        attr_reader :element_type
        delegate :type, :user_input_in_time_zone, :limit, :precision, :scale, to: :element_type

        def initialize element_type
          @element_type = element_type
        end

        def serialize value
          return super if value.nil?
          return super unless @element_type.is_a? Type::Decimal
          return super unless value.respond_to? :map

          # Convert a decimal (NUMERIC) array to a String array to prevent it from being encoded as a FLOAT64 array.
          value.map do |v|
            next if v.nil?
            v.to_s
          end
        end
      end
    end
  end
end
