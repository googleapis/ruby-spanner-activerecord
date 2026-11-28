# Copyright 2026 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# frozen_string_literal: true

require "test_helper"
require "models/author"

module ActiveRecord
  module Model
    class PreventingWritesTest < SpannerAdapter::TestCase
      include SpannerAdapter::Associations::TestHelper

      def setup
        super
        @author = Author.create! name: "Original"
      end

      def teardown
        super
        Author.destroy_all
      end

      def test_reads_succeed_while_preventing_writes
        ActiveRecord::Base.while_preventing_writes do
          found = Author.find @author.id
          assert_equal "Original", found.name

          hinted = Author.optimizer_hints("statement_hint: @{USE_ADDITIONAL_PARALLELISM=true}").find @author.id
          assert_equal "Original", hinted.name

          ActiveRecord::Base.transaction isolation: :read_only do
            assert_equal "Original", Author.find(@author.id).name
          end
        end
      end

      def test_mutations_and_dml_and_ddl_raise_read_only_error_without_modifying_data
        ActiveRecord::Base.while_preventing_writes do
          assert_raises ActiveRecord::ReadOnlyError do
            Author.create! name: "Created"
          end

          assert_raises ActiveRecord::ReadOnlyError do
            @author.update! name: "Updated"
          end

          assert_raises ActiveRecord::ReadOnlyError do
            @author.destroy!
          end

          assert_raises ActiveRecord::ReadOnlyError do
            Author.delete_all
          end

          assert_raises ActiveRecord::ReadOnlyError do
            Author.where(id: @author.id).update_all name: "DmlUpdated"
          end

          assert_raises ActiveRecord::ReadOnlyError do
            Author
              .optimizer_hints("statement_hint: @{USE_ADDITIONAL_PARALLELISM=true}")
              .where(id: @author.id)
              .update_all name: "HintedUpdated"
          end

          assert_raises ActiveRecord::ReadOnlyError do
            ActiveRecord::Base.connection.truncate "authors"
          end

          assert_raises ActiveRecord::ReadOnlyError do
            ActiveRecord::Base.connection.execute_ddl "CREATE TABLE `blocked_table` (`id` INT64) PRIMARY KEY (`id`)"
          end

          assert_raises ActiveRecord::ReadOnlyError do
            ActiveRecord::Base.transaction isolation: :pdml do
              Author.where(id: @author.id).update_all name: "PdmlUpdated"
            end
          end
        end

        assert_equal [@author.id], Author.where(id: @author.id).pluck(:id)
        assert_equal "Original", Author.find(@author.id).name
        refute ActiveRecord::Base.connection.table_exists?("blocked_table")
      end
    end
  end
end
