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

module Google
  module Cloud
    module Spanner
      class Project
        def create_session instance_id, database_id, labels: nil
          ensure_service!

          grpc = @service.create_session(
            database_path(instance_id, database_id),
            labels: labels
          )
          Session.from_grpc grpc, @service
        end
      end

      class Session
        def commit_transaction transaction
          ensure_service!

          resp = service.commit(
            path,
            transaction.commit.mutations,
            transaction_id: transaction.transaction_id
          )
          @last_updated_at = Time.now
          Convert.timestamp_to_time resp.commit_timestamp
        end

        def snapshot strong: nil,
                     timestamp: nil, read_timestamp: nil,
                     staleness: nil, exact_staleness: nil
          validate_snapshot_args! strong: strong, timestamp: timestamp,
                                  read_timestamp: read_timestamp,
                                  staleness: staleness,
                                  exact_staleness: exact_staleness
          ensure_service!
          if Thread.current[:transaction_id]
            raise "Nested snapshots are not allowed"
          end

          snp_grpc = service.create_snapshot \
            path, timestamp: (timestamp || read_timestamp),
            staleness: (staleness || exact_staleness)
          Thread.current[:transaction_id] = snp_grpc.id
          snp = Snapshot.from_grpc snp_grpc, self
          yield snp if block_given?
        ensure
          Thread.current[:transaction_id] = nil
        end

        private

        ##
        # Check for valid snapshot arguments
        def validate_snapshot_args! strong: nil,
                                    timestamp: nil, read_timestamp: nil,
                                    staleness: nil, exact_staleness: nil
          valid_args_count = [
            strong, timestamp, read_timestamp, staleness, exact_staleness
          ].compact.count
          return true if valid_args_count <= 1
          raise ArgumentError,
                "Can only provide one of the following arguments: " \
                "(strong, timestamp, read_timestamp, staleness, " \
                "exact_staleness)"
        end
      end

      class Transaction
        attr_accessor :seqno, :commit
      end
    end
  end
end
