# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Spanner
      module Quoting
        def quote_column_name name
          self.class.quoted_column_names[name] ||= "`#{super.gsub '`', '``'}`"
        end

        def quote_table_name name
          self.class.quoted_table_names[name] ||= super.gsub(".", "`.`").freeze
        end

        STR_ESCAPE_REGX = /[\n\r'\\]/.freeze
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
      end
    end
  end
end
