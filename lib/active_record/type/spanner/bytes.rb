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
        def deserialize value
          # Set this environment variable to disable de-serializing BYTES
          # to a StringIO instance.
          return super if ENV["SPANNER_BYTES_DESERIALIZE_DISABLED"]

          return super value if value.nil?
          return StringIO.new Base64.strict_decode64(value) if value.is_a? ::String
          value
        end

        def serialize value
          return super value if value.nil?

          if value.respond_to?(:read) && value.respond_to?(:rewind)
            value.rewind
            value = value.read
          end

          Base64.strict_encode64 value.force_encoding("ASCII-8BIT")
        end
      end
    end
  end
end
