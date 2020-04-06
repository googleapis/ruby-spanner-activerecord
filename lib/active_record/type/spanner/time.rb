# frozen_string_literal: true

module ActiveRecord
  module Type
    module Spanner
      class Time < ActiveRecord::Type::Time
        def serialize value
          value = super
          value.acts_like?(:time) ? value.utc.rfc3339(9) : value
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
