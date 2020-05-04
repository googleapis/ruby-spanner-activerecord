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


require "activerecord_spanner_adapter/index/column"

module ActiveRecordSpannerAdapter
  class Index
    attr_accessor :table, :name, :columns, :type, :unique, :null_filtered,
                  :interleve_in, :storing, :state

    def initialize \
        table,
        name,
        columns,
        type: nil,
        unique: false,
        null_filtered: false,
        interleve_in: nil,
        storing: nil,
        state: nil
      @table = table.to_s
      @name = name.to_s
      @columns = Array(columns)
      @type = type
      @unique = unique
      @null_filtered = null_filtered
      @interleve_in = interleve_in unless interleve_in.to_s.empty?
      @storing = storing || []
      @state = state
    end

    def primary?
      @type == "PRIMARY_KEY"
    end

    def columns_by_position
      @columns.select(&:ordinal_position).sort do |c1, c2|
        c1.ordinal_position <=> c2.ordinal_position
      end
    end

    def column_names
      columns_by_position.map &:name
    end

    def orders
      columns_by_position.each_with_object({}) do |c, r|
        r[c.name] = c.desc? ? :desc : :asc
      end
    end

    def options
      {
        name: name,
        order: orders,
        unique: unique,
        interleve_in: interleve_in,
        null_filtered: null_filtered,
        storing: storing
      }.delete_if { |_, v| v.nil? }
    end

    def rename_column_options old_column, new_column
      opts = options

      opts[:order].transform_keys do |key|
        key.to_s == new_column.to_s
      end

      columns = column_names.map do |c|
        c.to_s == old_column.to_s ? new_column : c
      end

      { options: opts, columns: columns }
    end
  end
end
