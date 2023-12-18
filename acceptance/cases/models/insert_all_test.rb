# Copyright 2022 Google LLC
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

      def test_insert
        value = { id: Author.next_sequence_value, name: "Alice" }

        assert_raise(NotImplementedError) { Author.insert(value) }
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

      def test_insert_all_with_transaction
        values = [
          { id: Author.next_sequence_value, name: "Alice" },
          { id: Author.next_sequence_value, name: "Bob" },
          { id: Author.next_sequence_value, name: "Carol" },
        ]

        ActiveRecord::Base.transaction do
          Author.insert_all!(values)
        end

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

        ActiveRecord::Base.transaction isolation: :buffered_mutations do
          Author.insert_all!(values)
        end

        authors = Author.all.order(:name)

        assert_equal "Alice", authors[0].name
        assert_equal "Bob", authors[1].name
        assert_equal "Carol", authors[2].name
      end

      def test_upsert
        Author.create id: 1, name: "David"
        authors = Author.all.order(:name)
        assert_equal 1, authors.length
        assert_equal "David", authors[0].name

        value = { id: 1, name: "Alice" }

        Author.upsert(value)

        authors = Author.all.order(:name)

        assert_equal 1, authors.length
        assert_equal "Alice", authors[0].name
      end

      def test_upsert_all
        Author.create id: 1, name: "David"
        authors = Author.all.order(:name)
        assert_equal 1, authors.length
        assert_equal "David", authors[0].name

        values = [
          { id: 1, name: "Alice" },
          { id: 2, name: "Bob" },
          { id: 3, name: "Carol" },
        ]

        Author.upsert_all(values)

        authors = Author.all.order(:name)

        assert_equal 3, authors.length
        assert_equal "Alice", authors[0].name
        assert_equal "Bob", authors[1].name
        assert_equal "Carol", authors[2].name
      end

      def test_upsert_all_with_transaction
        values = [
          { id: Author.next_sequence_value, name: "Alice" },
          { id: Author.next_sequence_value, name: "Bob" },
          { id: Author.next_sequence_value, name: "Carol" },
        ]

        err = assert_raise(NotImplementedError) do
          ActiveRecord::Base.transaction do
            Author.upsert_all(values)
          end
        end
        assert_match "Use upsert outside a transaction block", err.message
      end

      def test_upsert_all_with_buffered_mutation_transaction
        Author.create id: 1, name: "David"
        authors = Author.all.order(:name)
        assert_equal 1, authors.length
        assert_equal "David", authors[0].name

        values = [
          { id: 1, name: "Alice" },
          { id: 2, name: "Bob" },
          { id: 3, name: "Carol" },
        ]

        ActiveRecord::Base.transaction isolation: :buffered_mutations do
          Author.upsert_all(values)
        end

        authors = Author.all.order(:name)

        assert_equal 3, authors.length
        assert_equal "Alice", authors[0].name
        assert_equal "Bob", authors[1].name
        assert_equal "Carol", authors[2].name
      end
    end
  end
end
