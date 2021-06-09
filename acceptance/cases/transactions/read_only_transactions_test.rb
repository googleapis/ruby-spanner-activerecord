# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"
require "models/organization"

module ActiveRecord
  module Transactions
    class ReadOnlyTransactionsTest < SpannerAdapter::TestCase
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

      def test_read_in_snapshot
        Base.transaction isolation: :read_only do
          org = Organization.find @organization.id
          assert_equal "Organization 1", org.name
        end
      end

      def test_snapshot_does_not_see_new_changes
        Base.transaction isolation: :read_only do
          org = Organization.find @organization.id
          assert_equal "Organization 1", org.name

          # Update the name of the organization using a separate thread (and separate transaction).
          t = Thread.new { organization.update(name: "New name") }
          t.join

          # Reload the record using the current snapshot. The change will not be visible.
          org.reload
          assert_equal "Organization 1", org.name
        end

        # Now read the record outside of the snapshot. The new value should be visible.
        org = Organization.find @organization.id
        assert_equal "New name", org.name
      end

      def test_write_in_snapshot
        Base.transaction isolation: :read_only do
          err = assert_raises ActiveRecord::StatementInvalid do
            Organization.create(name: "Created in read-only transaction")
          end
          assert err.cause.is_a?(Google::Cloud::InvalidArgumentError)
        end
      end
    end
  end
end
