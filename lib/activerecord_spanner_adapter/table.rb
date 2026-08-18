# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "activerecord_spanner_adapter/table/column"

module ActiveRecordSpannerAdapter
  class Table
    attr_accessor :name
    attr_accessor :on_delete
    attr_accessor :parent_table
    attr_accessor :schema_name
    attr_accessor :catalog
    attr_accessor :indexes
    attr_accessor :columns
    attr_accessor :foreign_keys

    # parent_table == interleave_in
    def initialize \
        name,
        parent_table: nil,
        on_delete: nil,
        schema_name: nil,
        catalog: nil
      @name = name.to_s
      @parent_table = parent_table.to_s if parent_table
      @on_delete = on_delete
      @schema_name = schema_name
      @catalog = catalog
      @columns = []
      @indexes = []
      @foreign_keys = []
    end

    def primary_keys
      columns.select(&:primary_key).map(&:name)
    end

    def cascade?
      @on_delete == "CASCADE"
    end
  end
end
