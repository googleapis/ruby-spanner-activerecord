# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"

module ActiveRecord
  module Type
    class TextTest < SpannerAdapter::TestCase
      include SpannerAdapter::Types::TestHelper

      def test_convert_to_sql_type
        assert_equal "STRING(MAX)", connection.type_to_sql(:text)
        assert_equal "STRING(1024)", connection.type_to_sql(:text, limit: 1024)
      end

      def test_set_text_in_create
        text = "a" * 1000
        record = TestTypeModel.create(bio: text)
        record.reload

        assert_equal text, record.bio
      end
    end
  end
end