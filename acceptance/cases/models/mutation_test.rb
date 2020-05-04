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
require "models/author"
require "models/post"
require "models/comment"
require "models/address"
require "models/organization"

module ActiveRecord
  module Model
    class MutationTest < SpannerAdapter::TestCase
      include SpannerAdapter::Associations::TestHelper

      attr_accessor :author, :post, :comment

      def setup
        super

        @author = Author.create name: "David"
        @post = Post.create title: "Title - 1", author: author
        @comment = Comment.create comment: "Comment - 1", post: post
      end

      def teardown
        super
        Comment.destroy_all
        Post.destroy_all
        Author.destroy_all
        Organization.destroy_all
      end

      def test_update_all
        organization = Organization.create name: "Org - 1"
        organization.authors << author
        organization.authors << Author.new(name: "John")

        organization.reload

        assert_equal 2, organization.authors.where(registered_date: nil).count

        date = Date.new(2020, 01, 31)
        organization.authors.update_all(registered_date: date)

        assert_equal 0, organization.authors.where(registered_date: nil).count
        assert_equal 2, organization.authors.where(registered_date: date).count
      end

      def test_offset_and_limit_update
        post = Post.create title: "Title - 1", author: author
        5.times.each do |i|
          Comment.create comment: "Comment - #{i+1}", post: post
        end

        assert_equal 5, post.comments.count
        assert_equal 3, post.comments.offset(1).limit(3).update_all(comment: "New Comment")

        post.reload
        assert_equal 3, post.comments.where(comment: "New Comment").count
      end

      def test_update_all_with_joins
        post = Post.create title: "Title - 1", author: author
        post.comments << Comment.new(comment: "Comment - 1")

        posts = Post.joins(:comments).where(comments: { comment: "Comment - 1" })

        assert_equal true, posts.exists?
        assert_equal posts.count, posts.update_all(title: "Title - 1 Update")
      end

      def test_update_counters_with_joins
        post = Post.create title: "Title - 1", author: author
        assert_nil post.comments_count

        post.comments << Comment.new(comment: "Comment - 201")
        assert_equal 1, post.reload.comments_count

        Post.joins(:comments).where(comments: { comment: "Comment - 201" }).update_counters(comments_count: 10)

        assert_equal 11, post.reload.comments_count
      end

      def test_destroy_all
        authors = Author.where name: "David"

        assert_equal [author], authors.to_a

        authors.destroy_all
        assert_equal 0, Author.count
      end

      def test_dependent_destroy
        organization = Organization.create name: "Org - 1"
        organization.authors << author
        organization.authors << Author.new(name: "John")

        organization.reload
        assert_equal 2, organization.authors.count

        organization.destroy

        assert_nil Organization.find_by(id: organization.id)
        assert_equal 0, Author.count
      end

      def test_delete_all
        assert_equal 1, Author.count

        Author.delete_all

        assert_equal 0, Author.count
      end
    end
  end
end