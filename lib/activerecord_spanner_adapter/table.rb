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
