# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

module ActiveRecord
  module Type
    module Spanner
      class Time < ActiveRecord::Type::DateTime
        def cast_value value
          if value.is_a? ::String
            return if value.empty?
            begin
              if ActiveRecord.default_timezone == :utc
                ::DateTime.parse(value).to_time.getutc
              else
                ::Time.parse(value).getlocal
              end
            rescue StandardError
              super
            end
          else
            super
          end
        end

        def serialize_with_isolation_level value, isolation_level
          if value == :commit_timestamp
            return "PENDING_COMMIT_TIMESTAMP()" if isolation_level == :dml
            return "spanner.commit_timestamp()" if isolation_level == :mutation
          end

          serialize value
        end

        def serialize value
          val = super value
          val.acts_like?(:time) ? val.utc.rfc3339(9) : val
        end

        def value_from_multiparameter_assignment values
          defaults = { 1 => 2000, 2 => 1, 3 => 1 }
          super defaults.merge(values)
        end

        private

        def apply_seconds_precision value
          value
        end
      end
    end
  end
end
