# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"

module ActiveRecord
  class Migration
    class RenameColumnsTest < SpannerAdapter::TestCase
      include SpannerAdapter::Migration::TestHelper

      class RenameColumnPost < ActiveRecord::Base
      end

      class RenameColumnComment < ActiveRecord::Base
      end

      def setup
        skip_test_table_create!
        super

        connection.ddl_batch do
          connection.drop_table :rename_column_comments, if_exists: true
          connection.drop_table :rename_column_posts, if_exists: true

          connection.create_table(:rename_column_posts) do |t|
            t.string :name, limit: 128
            t.integer :comment_count
          end

          connection.create_table(:rename_column_comments) do |t|
            t.string :comment
            # The Spanner ActiveRecord adapter does not support creating an index on a column that also has a foreign key,
            # as Cloud Spanner automatically creates a managed index for the foreign key. The index is therefore created
            # separately.
            t.references :rename_column_post, foreign_key: true
            t.index :rename_column_post_id
          end
        end

        RenameColumnPost.reset_column_information
        RenameColumnComment.reset_column_information
      end

      def teardown
        super
        connection.drop_table :rename_column_comments, if_exists: true
        connection.drop_table :rename_column_posts, if_exists: true
      end

      def test_rename_column
        assert connection.column_exists?(:rename_column_posts, :name, :string, limit: 128)

        RenameColumnPost.create!(name: "Post1", comment_count: 1)
        RenameColumnPost.create!(name: "Post2", comment_count: 2)

        connection.rename_column :rename_column_posts, :name, :title

        RenameColumnPost.reset_column_information

        assert connection.column_exists?(:rename_column_posts, :title, :string, limit: 128)

        assert_equal ["Post1", "Post2"].sort, RenameColumnPost.pluck(:title).sort
        assert_equal [1, 2], RenameColumnPost.pluck(:comment_count).sort
      end

      def test_rename_column_with_index_and_foreign_key
        assert connection.column_exists?(:rename_column_comments, :rename_column_post_id, :integer)
        assert connection.index_exists?(:rename_column_comments, :rename_column_post_id)
        assert connection.foreign_key_exists?(:rename_column_comments, :rename_column_posts)

        post = RenameColumnPost.create!(name: "Post1")
        RenameColumnComment.create!(comment: "Comment1", rename_column_post_id: post.id)
        RenameColumnComment.create!(comment: "Comment2", rename_column_post_id: post.id)

        connection.rename_column :rename_column_comments, :rename_column_post_id, :post_id

        RenameColumnComment.reset_column_information

        assert connection.column_exists?(:rename_column_comments, :post_id, :integer)
        assert connection.index_exists?(:rename_column_comments, :post_id)

        foreign_keys = connection.foreign_keys("rename_column_comments")
        assert_equal 1, foreign_keys.length

        fk = foreign_keys.first
        assert_equal "rename_column_comments", fk.from_table
        assert_equal "post_id", fk.column

        assert_equal [post.id, post.id].sort, RenameColumnComment.pluck(:post_id)
      end
    end
  end
end