# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"
require "models/author"
require "models/post"
require "models/comment"
require "models/address"

module ActiveRecord
  module Model
    class QueryTest < SpannerAdapter::TestCase
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
      end

      def test_in_clause_is_correctly_sliced
        author2 = Author.create name: "John"

        assert_equal 2, Author.count
        assert_equal [author], Author.where(name: "David", id: [author.id, author2.id])
      end

      def test_type_casting_nested_joins
        assert_equal [comment], Comment.joins(post: :author).where(authors: { id: author.id })
      end

      def test_where_copies_bind_params
        posts  = author.posts.where("posts.id = #{post.id}")
        joined = Post.where(id: posts)

        assert_operator joined.length, :>, 0

        joined.each { |j_post|
          assert_equal author, j_post.author
          assert_equal post.id, j_post.id
        }
      end

      def test_where_or_with_relation
        post2 = Post.create title: "Title - 2", author: author
        expected = Post.where("id = #{post.id} or id = #{post2.id}").to_a
        assert_equal expected, Post.where("id = #{post.id}").or(Post.where("id = #{post2.id}")).to_a
      end

      def test_joins_and_preload
        assert_nothing_raised do
          Post.includes(:author).or(Post.includes(:author))
          Post.eager_load(:author).or(Post.eager_load(:author))
          Post.preload(:author).or(Post.preload(:author))
          Post.group(:author_id).or(Post.group(:author_id))
          Post.joins(:author).or(Post.joins(:author))
          Post.left_outer_joins(:author).or(Post.left_outer_joins(:author))
          Post.from("posts")
        end
      end

      def test_not_inverts_where_clause
        relation = Post.where.not(title: "hello")
        expected_where_clause = Post.where(title: "hello").where_clause.invert

        assert_equal expected_where_clause, relation.where_clause
      end

      def test_range
        post2 = Post.create title: "Title - 1", author: author
        comment2 = Comment.create comment: "Comment - 2", post: post2

        assert_equal 2, Post.where(comments_count: 1..3).count
      end

      def test_with_infinite_upper_bound_range
        assert_equal 1, Post.where(comments_count: 1..Float::INFINITY).count
      end

      def test_offset_and_limit
        post = Post.create title: "Title - 1", author: author
        5.times.each do |i|
          Comment.create comment: "Comment - #{i+1}", post: post
        end

        assert_equal 5, post.comments.count
        assert_equal 3, Comment.offset(1).limit(3).count
      end

      def test_select
        post = Post.select(:title).to_a.first

        assert_nil post.id
        assert_equal "Title - 1", post.title
      end

      def test_order_and_pluck
        post = Post.create title: "Title - 2", author: author
        titles = Post.order("title").pluck("posts.title")

        assert_equal ["Title - 1", "Title - 2"], titles
      end

      def test_time_value
        time_value = Time.new(2016, 05, 11, 19, 0, 0)
        post = Post.create(published_time: time_value)
        assert_equal post, Post.find_by(published_time: time_value)
      end

      def test_timestamp_value
        timestamp_value = Time.now
        post = Post.create(published_time: timestamp_value)
        assert_equal post, Post.find_by(published_time: timestamp_value)
      end

      def test_date_value
        date = Date.new(2016, 05, 11)
        post = Post.create(post_date: date)
        assert_equal post, Post.find_by(post_date: date)
      end

      def test_relation_merging
        post.comments << Comment.new(comment: "Comment - 2")

        posts = Post.where("comments_count >= 0").merge(Post.limit(2)).merge(Post.order("id ASC"))

        assert_equal [post], posts.to_a
      end
    end
  end
end