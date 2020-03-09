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

        def quoted_binary value
          "b'#{value}'"
        end
      end
    end
  end
end
