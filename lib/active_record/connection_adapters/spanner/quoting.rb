# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Spanner
      module Quoting
        def quoted_binary value
          "b'#{value}'"
        end
      end
    end
  end
end
