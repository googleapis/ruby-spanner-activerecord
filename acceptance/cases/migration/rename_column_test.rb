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

        connection.drop_table :rename_column_comments, if_exists: true
        connection.drop_table :rename_column_posts, if_exists: true

        connection.create_table(:rename_column_posts) do |t|
          t.string :name, limit: 128
          t.integer :comment_count
        end

        connection.create_table(:rename_column_comments) do |t|
          t.string :comment
          t.references :rename_column_post, index: true, foreign_key: true
        end
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