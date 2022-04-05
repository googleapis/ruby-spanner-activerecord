# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"
require "models/author"

module ActiveRecord
  module Model
    class InsertAllTest < SpannerAdapter::TestCase
      include SpannerAdapter::Associations::TestHelper

      def setup
        super
      end

      def teardown
        super
        Author.destroy_all
      end

      def test_insert_all
        values = [
          { id: Author.next_sequence_value, name: "Alice" },
          { id: Author.next_sequence_value, name: "Bob" },
          { id: Author.next_sequence_value, name: "Carol" },
        ]

        assert_raise(NotImplementedError) { Author.insert_all(values) }
      end

      def test_insert_all!
        values = [
          { id: Author.next_sequence_value, name: "Alice" },
          { id: Author.next_sequence_value, name: "Bob" },
          { id: Author.next_sequence_value, name: "Carol" },
        ]

        Author.insert_all!(values)

        authors = Author.all.order(:name)

        assert_equal "Alice", authors[0].name
        assert_equal "Bob", authors[1].name
        assert_equal "Carol", authors[2].name
      end

      def test_insert_all_with_buffered_mutation_transaction
        values = [
          { id: Author.next_sequence_value, name: "Alice" },
          { id: Author.next_sequence_value, name: "Bob" },
          { id: Author.next_sequence_value, name: "Carol" },
        ]

        assert_raise(RuntimeError) do
          ActiveRecord::Base.transaction isolation: :buffered_mutations do
            Author.insert_all!(values)
          end
        end
      end

      def test_upsert_all_with_buffered_mutation_transaction
        values = [
          { id: Author.next_sequence_value, name: "Alice" },
          { id: Author.next_sequence_value, name: "Bob" },
          { id: Author.next_sequence_value, name: "Carol" },
        ]

        assert_raise(RuntimeError) do
          ActiveRecord::Base.transaction isolation: :buffered_mutations do
            Author.upsert_all(values)
          end
        end
      end
    end
  end
end
