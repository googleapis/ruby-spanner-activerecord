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
    class StringTest < SpannerAdapter::TestCase
      include SpannerAdapter::Types::TestHelper

      def test_convert_to_sql_type
        assert_equal "STRING(MAX)", connection.type_to_sql(:string)
        assert_equal "STRING(1024)", connection.type_to_sql(:string, limit: 1024)
      end

      def test_set_string_in_create
        description = "a" * 1000
        name = "Test name"
        record = TestTypeModel.create(description: description, name: name)
        record.reload

        assert_equal description, record.description
        assert_equal name, record.name
      end

      def test_set_string_with_max_limit_in_create
        str = "a" * 256

        assert_raise(ActiveRecord::StatementInvalid) {
          TestTypeModel.create(name: str)
        }
      end

      def test_escape_special_charaters_and_save
        str = [
          "Newline \n",
          "`Backtick`",
          "'Quote'",
          "Bell \a",
          "Backspace \b",
          "Formfeed \f",
          "Carriage Return \r",
          "Tab \t",
          "Vertical Tab \v",
          "Backslash \\",
          "Question Mark \?",
          "Double Quote \"",
        ].join (" ")

        record = TestTypeModel.new(description: str)
        assert_equal str, record.description

        record.save!
        assert_equal str, record.description

        record.reload
        assert_equal str, record.description
      end

      def test_save_special_charaters
        str = "Hello Seocial Chars : € à ö ¿ © 😎"

        record = TestTypeModel.new(description: str)
        assert_equal str, record.description

        record.save!
        assert_equal str, record.description

        record.reload
        assert_equal str, record.description
      end
    end
  end
end