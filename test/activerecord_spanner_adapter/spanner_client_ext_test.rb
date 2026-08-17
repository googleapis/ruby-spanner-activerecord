# Copyright 2026 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "test_helper"

class SpannerClientExtTest < TestHelper::MockActiveRecordTest
  def setup
    super
    grpc = Google::Cloud::Spanner::V1::Session.new name: "projects/p/instances/i/databases/d/sessions/s"
    service = MockGoogleSpanner::MockService.new
    @session = Google::Cloud::Spanner::Session.from_grpc grpc, service
  end

  def test_snapshot_from_grpc_arity_memoized
    arity = Google::Cloud::Spanner::Snapshot.method(:from_grpc).arity
    memoized_arity = Google::Cloud::Spanner::Session.snapshot_from_grpc_arity
    assert_equal arity, memoized_arity
  end

  def test_create_snapshot_strong
    snapshot = @session.create_snapshot strong: true
    refute_nil snapshot
    assert_instance_of Google::Cloud::Spanner::Snapshot, snapshot
  end

  def test_create_snapshot_validates_multiple_arguments
    assert_raises ArgumentError do
      @session.create_snapshot strong: true, timestamp: Time.now
    end
  end

  def test_single_use_transaction_strong
    selector = Google::Cloud::Spanner::Session.single_use_transaction strong: true
    refute_nil selector
    assert selector.single_use.read_only.strong
  end

  def test_single_use_transaction_nil_or_empty
    assert_nil Google::Cloud::Spanner::Session.single_use_transaction(nil)
    assert_nil Google::Cloud::Spanner::Session.single_use_transaction({})
  end
end
