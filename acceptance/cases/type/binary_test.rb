# frozen_string_literal: true


require "test_helper"

module ActiveRecord
  module Type
    class BinaryTest < SpannerAdapter::TestCase
      include SpannerAdapter::Types::TestHelper

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