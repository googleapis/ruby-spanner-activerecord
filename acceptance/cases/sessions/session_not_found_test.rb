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

module ActiveRecord
  module Sessions

    # Verifies that the adapter can handle a Session not found error in all (common) scenarios.
    class SessionNotFoundTest < SpannerAdapter::TestCase
      include SpannerAdapter::Associations::TestHelper

      attr_accessor :organization

      def setup
        super

        @organization = Organization.create name: "Organization 1"
      end

      def teardown
        super

        Organization.destroy_all
      end

      def client
        @client ||= Google::Cloud::Spanner::V1::Spanner::Client.new do |config|
          config.credentials = ENV["SPANNER_EMULATOR_HOST"] \
            ? :this_channel_is_insecure \
            : ENV["SPANNER_KEYFILE_JSON"]
          config.endpoint = ENV["SPANNER_EMULATOR_HOST"] if ENV["SPANNER_EMULATOR_HOST"]
        end
      end

      def delete_all_sessions
        sessions = client.list_sessions(
          Google::Cloud::Spanner::V1::ListSessionsRequest.new(
            database: "projects/#{ENV["SPANNER_PROJECT"]}/instances/#{ENV["SPANNER_TEST_INSTANCE"]}/databases/#{$spanner_test_database}"
          )
        )
        sessions.each do |session|
          client.delete_session Google::Cloud::Spanner::V1::DeleteSessionRequest.new name: session.name
        end
      end

      def test_single_read
        delete_all_sessions
        organization = Organization.find_by id: @organization.id
        refute_nil organization
      end

      def test_single_mutation
        delete_all_sessions
        id = Organization.create name: "Organization 2"
        assert_equal "Organization 2", Organization.find_by(id: id).name
      end

      def test_batch_mutation
        delete_all_sessions
        Organization.create([{name: "Organization 2"}, {name: "Organization 3"}])
        assert_equal 3, Organization.count
      end

      def test_begin_transaction
        delete_all_sessions
        Organization.transaction do
          organization = Organization.find_by id: @organization.id
          refute_nil organization
        end
      end

      def test_read_in_transaction
        attempts = 0
        Organization.transaction do
          attempts += 1
          delete_all_sessions if attempts == 1
          organization = Organization.find_by id: @organization.id
          refute_nil organization
        end
        # The transaction could also be aborted by the backend, hence the > 1.
        assert attempts > 1, "Should retry at least once"
      end

      def test_dml_in_transaction
        id = nil
        attempts = 0
        Organization.transaction do
          attempts += 1
          delete_all_sessions if attempts == 1
          id = Organization.create name: "Organization 2"
        end
        assert attempts > 1, "Should retry at least once"
        assert_equal "Organization 2", Organization.find_by(id: id).name
      end

      def test_commit
        attempts = 0
        Organization.transaction do
          Organization.find_by id: @organization.id
          attempts += 1
          # The following is a trick for the emulator only. If a session on the emulator has an active transaction,
          # and that session is deleted, the emulator still thinks that the transaction is active.
          # See https://github.com/GoogleCloudPlatform/cloud-spanner-emulator/issues/30
          Base.connection.current_spanner_transaction.shoot_and_forget_rollback if ENV["SPANNER_EMULATOR_HOST"] && attempts == 1
          delete_all_sessions if attempts == 1
        end
        assert attempts > 1, "Should retry at least once"
      end
    end
  end
end
