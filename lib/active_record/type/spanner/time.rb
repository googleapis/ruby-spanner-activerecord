# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

module ActiveRecord
  module Type
    module Spanner
      class Time < ActiveRecord::Type::Time
        def serialize value, *options
          return "PENDING_COMMIT_TIMESTAMP()" if value == :commit_timestamp && options.length && options[0] == :dml
          return "spanner.commit_timestamp()" if value == :commit_timestamp && options.length && options[0] == :mutation
          val = super value
          val.acts_like?(:time) ? val.utc.rfc3339(9) : val
        end

        def user_input_in_time_zone value
          return value.in_time_zone if value.is_a? ::Time
          super value
        end

        private

        def cast_value value
          if value.is_a? ::String
            value = value.empty? ? nil : ::Time.parse(value)
          end

          value
        end
      end
    end
  end
end
