# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"
require "models/singer"

module ActiveRecord
  module Model
    class GeneratedColumnTest < SpannerAdapter::TestCase
      include SpannerAdapter::Associations::TestHelper

      # Runs the given block in a transaction with the given isolation level, or without a transaction if isolation is
      # nil.
      def run_in_transaction isolation
        if isolation
          Base.transaction isolation: isolation do
            yield
          end
        else
          yield
        end
      end

      def test_create_non_null
        [nil, :serializable, :buffered_mutations].each do |isolation|
          singer = nil
          run_in_transaction isolation do
            singer = Singer.create first_name: "Pete", last_name: "Allison"
          end

          singer.reload
          assert_equal "Pete Allison", singer.full_name
        end
      end

      def test_create_null
        [nil, :serializable, :buffered_mutations].each do |isolation|
          singer = nil
          run_in_transaction isolation do
            singer = Singer.create last_name: "Allison"
          end

          singer.reload
          assert_equal "Allison", singer.full_name
        end
      end

      def test_update_non_null
        [nil, :serializable, :buffered_mutations].each do |isolation|
          singer = Singer.create first_name: "Pete", last_name: "Allison"
          singer.reload # reload to ensure the full_name attribute is populated.
          run_in_transaction isolation do
            singer.update first_name: "Alice"
          end

          singer.reload
          assert_equal "Alice Allison", singer.full_name
        end
      end

      def test_update_null
        [nil, :serializable, :buffered_mutations].each do |isolation|
          singer = Singer.create first_name: "Pete", last_name: "Allison"
          singer.reload # reload to ensure the full_name attribute is populated.
          run_in_transaction isolation do
            singer.update first_name: nil
          end

          singer.reload
          assert_equal "Allison", singer.full_name
        end
      end

      VERSION_7 = ActiveRecord.gem_version >= Gem::Version.create("7.0.0")

      def assert_raises_below_ar_7(ex, &test)
        if VERSION_7
          assert_nothing_raised &test
        else
          assert_raises ex, &test
        end
      end

      def test_create_with_value_for_generated_column
        # Note: The statement itself will not fail for an explicit transaction that uses buffered transactions.
        # Instead, the commit will fail. That is tested in a separate test case.
        [nil, :serializable].each do |isolation|
          run_in_transaction isolation do
            assert_raises_below_ar_7 ActiveRecord::StatementInvalid do
              singer = Singer.create first_name: "Pete", last_name: "Allison", full_name: "Alice Peterson"
              assert_equal "Pete Allison", singer.reload.full_name
            end
          end
        end
      end

      def test_create_with_value_for_generated_column_buffered_mutations
        # The transaction itself will raise an error, as the failure occurs during the commit.
        assert_raises_below_ar_7 ActiveRecord::StatementInvalid do
          singer = run_in_transaction :buffered_mutations do
            Singer.create first_name: "Pete", last_name: "Allison", full_name: "Alice Peterson"
          end
          assert_equal "Pete Allison", singer.reload.full_name
        end
      end

      def test_update_with_value_for_generated_column
        # Note: The statement itself will not fail for an explicit transaction that uses buffered transactions.
        # Instead, the commit will fail. That is tested in a separate test case.
        [nil, :serializable].each do |isolation|
          singer = Singer.create first_name: "Pete", last_name: "Allison"
          singer.reload # reload to ensure the full_name attribute is populated.
          run_in_transaction isolation do
            assert_raises_below_ar_7 ActiveRecord::StatementInvalid do
              Singer.update full_name: "Alice Peterson"
            end
          end
          assert_equal "Pete Allison", singer.reload.full_name
        end
      end

      def test_update_with_value_for_generated_column_buffered_mutations
        singer = Singer.create first_name: "Pete", last_name: "Allison"
        singer.reload # reload to ensure the full_name attribute is populated.
        # The transaction itself will raise an error, as the failure occurs during the commit.
        assert_raises_below_ar_7 ActiveRecord::StatementInvalid do
          run_in_transaction :buffered_mutations do
            Singer.update full_name: "Alice Peterson"
          end
        end
        assert_equal "Pete Allison", singer.reload.full_name
      end
    end
  end
end
