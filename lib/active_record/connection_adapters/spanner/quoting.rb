# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    QUOTED_COLUMN_NAMES = Concurrent::Map.new # :nodoc:
    QUOTED_TABLE_NAMES = Concurrent::Map.new # :nodoc:

    module Quoting
      module ClassMethods
        # This is used for ActiveRecord v8 and higher.
        def quote_column_name name
          QUOTED_COLUMN_NAMES[name] ||= "`#{name.to_s.gsub '`', '``'}`".freeze
        end

        def quote_table_name name
          QUOTED_TABLE_NAMES[name] ||= "`#{name.to_s.gsub '.', '`.`'}`".freeze
        end
      end
    end

    module Spanner
      module Quoting
        def quote_column_name name
          QUOTED_COLUMN_NAMES[name] ||= "`#{name.to_s.gsub '`', '``'}`".freeze
        end

        def quote_table_name name
          QUOTED_TABLE_NAMES[name] ||= "`#{name.to_s.gsub '.', '`.`'}`".freeze
        end

        STR_ESCAPE_REGX = /[\n\r'\\]/
        STR_ESCAPE_VALUES = {
          "\n" => "\\n", "\r" => "\\r", "'" => "\\'", "\\" => "\\\\"
        }.freeze

        private_constant :STR_ESCAPE_REGX, :STR_ESCAPE_VALUES

        def quote_string s
          s.gsub STR_ESCAPE_REGX, STR_ESCAPE_VALUES
        end

        def quoted_binary value
          "b'#{value}'"
        end

        def _type_cast value
          case value
          when Array
            ActiveSupport::JSON.encode value
          else
            super
          end
        end
      end
    end
  end
end
