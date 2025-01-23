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

        # This constructor intentionally does not call super.
        # rubocop:disable Lint/MissingSuper
        def initialize element_type
          @element_type = element_type
        end
        # rubocop:enable Lint/MissingSuper

        def cast value
          return super if value.nil?
          return super unless value.respond_to? :map

          value.map do |v|
            @element_type.cast v
          end
        end

        def serialize value
          return super if value.nil?
          return super unless value.respond_to? :map

          if @element_type.is_a? ActiveRecord::Type::Decimal
            # Convert a decimal (NUMERIC) array to a String array to prevent it from being encoded as a FLOAT64 array.
            value.map do |v|
              next if v.nil?
              v.to_s
            end
          else
            value.map do |v|
              @element_type.serialize v
            end
          end
        end
      end
    end
  end
end
