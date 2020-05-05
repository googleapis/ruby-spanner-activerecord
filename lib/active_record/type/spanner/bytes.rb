# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

module ActiveRecord
  module Type
    module Spanner
      class Bytes < ActiveRecord::Type::Binary
        def serialize value
          return super value if value.nil?

          if value.respond_to?(:read) && value.respond_to?(:rewind)
            value.rewind
            value = value.read
          end

          value = Base64.strict_encode64 value.force_encoding("ASCII-8BIT")
          super value
        end

        def deserialize value
          return if value.nil?
          return value.to_s if value.is_a? Type::Binary::Data
          return Base64.decode64 value.read if value.respond_to? :read

          Base64.decode64 value
        end
      end
    end
  end
end
