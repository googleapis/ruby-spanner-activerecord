# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"
require "models/author"
require "models/post"
require "models/comment"
require "models/organization"
require "models/table_with_sequence"

module ActiveRecord
  module Transactions
    class ReadWriteTransactionsTest < SpannerAdapter::TestCase
      include SpannerAdapter::Associations::TestHelper

      attr_accessor :organization, :author, :post, :comment

      def create_test_records
        @organization = Organization.create name: "Organization 1"
        @author = Author.create name: "David", organization: organization
        @post = Post.create title: "Title - 1", author: author
        @comment = Comment.create comment: "Comment - 1", post: post
      end

      def teardown
        super

        delete_test_records
      end

      def delete_test_records
        Comment.destroy_all
        Post.destroy_all
        Author.destroy_all
        Organization.destroy_all
      end

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

      def test_create_multiple_records
        [nil, :serializable, :buffered_mutations].each do |isolation|
          initial_author_count = Author.count
          initial_posts_count = Post.count
          initial_comment_count = Comment.count

          run_in_transaction isolation do
            author = Author.create name: "Author 1", organization: organization
            posts = Post.create [{title: "Post 1", author: author}, {title: "Post 2", author: author}]
            Comment.create [
                             {comment: "Comment 1", post: posts[0]},
                             {comment: "Comment 2", post: posts[1]}
                           ]
          end

          # Verify that all the records were created.
          assert_equal initial_author_count + 1, Author.count
          assert_equal initial_posts_count + 2, Post.count
          assert_equal initial_comment_count + 2, Comment.count
        end
      end

      def test_update_multiple_records
        [nil, :serializable, :buffered_mutations].each do |isolation|
          create_test_records

          run_in_transaction isolation do
            organization.update name: "Updated name #{isolation}"
            author.update name: "Updated name #{isolation}"
            post.update title: "Updated title #{isolation}"
            comment.update comment: "Updated comment #{isolation}"
          end

          assert_equal "Updated name #{isolation}", organization.reload.name
          assert_equal "Updated name #{isolation}", author.reload.name
          assert_equal "Updated title #{isolation}", post.reload.title
          assert_equal "Updated comment #{isolation}", comment.reload.comment
        end
      end

      def test_destroy_multiple_records
        [nil, :serializable, :buffered_mutations].each do |isolation|
          create_test_records

          run_in_transaction isolation do
            comment.destroy
            post.destroy
            author.destroy
            organization.destroy
          end

          assert_equal 0, Organization.count
          assert_equal 0, Author.count
          assert_equal 0, Post.count
          assert_equal 0, Comment.count
        end
      end

      def test_delete_multiple_records
        [nil, :serializable, :buffered_mutations].each do |isolation|
          create_test_records

          run_in_transaction isolation do
            comment.delete
            post.delete
            author.delete
            organization.delete
          end

          assert_equal 0, Organization.count
          assert_equal 0, Author.count
          assert_equal 0, Post.count
          assert_equal 0, Comment.count
        end
      end

      def test_destroy_parent_record
        [nil, :serializable, :buffered_mutations].each do |isolation|
          create_test_records

          run_in_transaction isolation do
            # Only destroy the top-level record. This should cascade to the author records, as those are
            # marked with `dependent: destroy`. The dependants of Author are however not marked with
            # `dependent: destroy`, which means that those will not be deleted, but the reference to Author will
            # be set to nil.
            organization.destroy
          end

          assert_equal 0, Organization.count
          assert_equal 0, Author.count
          assert_equal 1, Post.count # These are not marked with `dependent: destroy`
          assert_nil Post.find(post.id).author # The author is set to NULL instead of deleting the posts.
          assert_equal 1, Comment.count

          # Delete all remaining test records to make sure the next iteration starts clean.
          delete_test_records
        end
      end

      def test_multiple_consecutive_transactions
        isolation_levels = [nil, :serializable, :buffered_mutations]
        isolation_levels.each do |isolation|

          run_in_transaction isolation do
            create_test_records
          end

          isolation_levels.each do |isolation|
            run_in_transaction isolation do
              create_test_records
            end
          end

          transaction_count = isolation_levels.length + 1
          assert_equal transaction_count, Organization.count
          assert_equal transaction_count, Author.count
          assert_equal transaction_count, Post.count
          assert_equal transaction_count, Comment.count

          delete_test_records
        end
      end

      def test_read_your_writes
        [nil, :serializable, :buffered_mutations].each do |isolation|
          initial_author_count = Author.count
          initial_posts_count = Post.count
          initial_comment_count = Comment.count

          run_in_transaction isolation do
            author = Author.create name: "Author 1", organization: organization
            posts = Post.create [{title: "Post 1", author: author}, {title: "Post 2", author: author}]
            Comment.create [
                             {comment: "Comment 1", post: posts[0]},
                             {comment: "Comment 2", post: posts[1]}
                           ]

            # Verify that the new records are visible, unless we are working with an actual transaction that
            # uses buffered mutations. Implicit transactions (isolation = nil) will also use mutations, but each
            # create call will automatically be committed, and the changes will be visible here.
            unless isolation == :buffered_mutations
              assert_equal initial_author_count + 1, Author.count
              assert_equal initial_posts_count + 2, Post.count
              assert_equal initial_comment_count + 2, Comment.count
            else
              assert_equal initial_author_count, Author.count
              assert_equal initial_posts_count, Post.count
              assert_equal initial_comment_count, Comment.count
            end
          end
        end
      end

      def test_create_commit_timestamp
        [nil, :serializable, :buffered_mutations].each do |isolation|
          current_timestamp = Organization.connection.select_all("SELECT CURRENT_TIMESTAMP() AS t").to_a[0]["t"]
          organization = nil
          run_in_transaction isolation do
            organization = Organization.create name: "Org with commit timestamp", last_updated: :commit_timestamp
          end

          organization.reload
          assert organization.last_updated
          assert organization.last_updated > current_timestamp
        end
      end

      def test_update_commit_timestamp
        [nil, :serializable, :buffered_mutations].each do |isolation|
          organization = Organization.create name: "Org without commit timestamp"
          current_timestamp = Organization.connection.select_all("SELECT CURRENT_TIMESTAMP() AS t").to_a[0]["t"]

          run_in_transaction isolation do
            organization.update last_updated: :commit_timestamp
          end

          organization.reload
          assert organization.last_updated
          assert organization.last_updated > current_timestamp
        end
      end

      def test_pdml
        create_test_records
        assert Comment.count > 0

        Comment.transaction isolation: :pdml do
          Comment.delete_all
        end

        assert_equal 0, Comment.count
      end

      def test_create_record_with_sequence
        record = TableWithSequence.create name: "Some name", age: 40
        assert record.id, "ID should be generated and returned by the database"
        assert record.id > 0, "ID should be positive" unless ENV["SPANNER_EMULATOR_HOST"]
      end

      def test_create_record_with_sequence_in_transaction
        record = TableWithSequence.transaction do
          TableWithSequence.create name: "Some name", age: 40
        end
        assert record.id, "ID should be generated and returned by the database"
        assert record.id > 0, "ID should be positive" unless ENV["SPANNER_EMULATOR_HOST"]
      end

      def test_create_record_with_sequence_using_mutations
        err = assert_raises ActiveRecord::StatementInvalid do
          TableWithSequence.transaction isolation: :buffered_mutations do
            TableWithSequence.create name: "Foo", age: 50
          end
        end
        assert_equal "Mutations cannot be used to create records that use a sequence to generate the primary key. TableWithSequence uses test_sequence.", err.message
      end
    end
  end
end
