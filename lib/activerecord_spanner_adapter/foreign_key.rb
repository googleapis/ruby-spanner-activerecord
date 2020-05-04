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
  class ForeignKey
    attr_accessor :table_name, :name, :columns, :ref_table, :ref_columns,
                  :on_delete, :on_update

    def initialize \
        table_name,
        name,
        columns,
        ref_table,
        ref_columns,
        on_delete: nil,
        on_update: nil
      @table_name = table_name
      @name = name
      @columns = Array(columns)
      @ref_table = ref_table
      @ref_columns = Array(ref_columns)
      @on_delete = on_delete unless on_delete == "NO ACTION"
      @on_update = on_update unless on_update == "NO ACTION"
    end
  end
end
