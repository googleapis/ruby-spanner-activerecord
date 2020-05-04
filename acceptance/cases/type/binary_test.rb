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

# frozen_string_literal: true

require "test_helper"

module ActiveRecord
  module Type
    class BinaryTest < SpannerAdapter::TestCase
      include SpannerAdapter::Types::TestHelper

      def test_convert_to_sql_type
        assert_equal "BYTES(MAX)", connection.type_to_sql(:binary)
        assert_equal "BYTES(1024)", connection.type_to_sql(:binary, limit: 1024)
      end

      def test_set_binary_data_io_in_create
        data = StringIO.new "hello"

        record = TestTypeModel.create(data: data)
        record.reload

        assert_equal "hello", record.data
      end

      def test_set_binary_data_byte_string_in_create
        data = StringIO.new "hello1"

        record = TestTypeModel.create(data: data.read)
        record.reload

        assert_equal "hello1", record.data
      end

      def test_check_max_limit
        str = "a" * 256

        assert_raise(ActiveRecord::StatementInvalid) {
          TestTypeModel.create(name: str)
        }
      end

      def test_set_binary_data_from_file
        Tempfile.create do |f|
          f << "hello 123"

          record = TestTypeModel.create(file: f)
          record.reload

          assert_equal "hello 123", record.file
        end
      end
    end
  end
end