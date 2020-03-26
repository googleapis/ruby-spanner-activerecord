# frozen_string_literal: true

module ActiveRecord
  module Type
    module Spanner
      class Time < ActiveRecord::Type::Time
        def serialize value
          value = super value
          value.acts_like?(:time) ? value.utc.rfc3339(9) : value
        end
      end
    end
  end
end
