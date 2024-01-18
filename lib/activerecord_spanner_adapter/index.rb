# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "activerecord_spanner_adapter/index/column"

module ActiveRecordSpannerAdapter
  class Index
    attr_accessor :schema, :table, :name, :columns, :type, :unique, :null_filtered,
                  :interleave_in, :storing, :state

    def initialize \
        table,
        name,
        columns,
        type: nil,
        unique: false,
        null_filtered: false,
        interleave_in: nil,
        storing: nil,
        state: nil,
        schema: ""
      @schema = schema.to_s
      @table = table.to_s
      @name = name.to_s
      @columns = Array(columns)
      @type = type
      @unique = unique
      @null_filtered = null_filtered
      @interleave_in = interleave_in unless interleave_in.to_s.empty?
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
      columns_by_position.map(&:name)
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
        interleave_in: interleave_in,
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
