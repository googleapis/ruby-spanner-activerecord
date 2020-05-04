# The MIT License (MIT)
#
# Copyright (c) 2020 Google LLC.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# ITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

module ActiveRecordSpannerAdapter
  class Table
    class Column
      attr_accessor :table_name, :name, :type, :limit, :ordinal_position,
                    :allow_commit_timestamp, :default, :primary_key
      attr_writer :nullable

      def initialize \
          table_name,
          name,
          type,
          limit: nil,
          ordinal_position: nil,
          nullable: true,
          allow_commit_timestamp: nil,
          default: nil
        @table_name = table_name.to_s
        @name = name.to_s
        @type = type
        @limit = limit
        @nullable = nullable != false
        @ordinal_position = ordinal_position
        @allow_commit_timestamp = allow_commit_timestamp
        @default = default
        @primary_key = false
      end

      def nullable
        return false if primary_key
        @nullable
      end

      def spanner_type
        return "#{type}(#{limit || 'MAX'})" if limit_allowed?
        type
      end

      def options
        {
          limit: limit,
          null: nullable,
          allow_commit_timestamp: allow_commit_timestamp
        }.delete_if { |_, v| v.nil? }
      end

      private

      def limit_allowed?
        ["BYTES", "STRING"].include? type
      end
    end
  end
end
