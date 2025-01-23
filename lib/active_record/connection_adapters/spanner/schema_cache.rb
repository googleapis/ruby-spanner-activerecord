# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

module ActiveRecord
  module ConnectionAdapters
    class SpannerSchemaCache
      def initialize conn
        @connection = conn
        @primary_and_parent_keys = {}
      end

      def primary_and_parent_keys table_name
        @primary_and_parent_keys[table_name] ||=
          @connection.primary_and_parent_keys table_name
      end

      def clear!
        @primary_and_parent_keys.clear
      end
    end
  end
end
