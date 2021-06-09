# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.


module Google
  module Cloud
    module Spanner
      class Project
        def create_session instance_id, database_id, labels: nil
          ensure_service!

          grpc = @service.create_session(
            Admin::Database::V1::DatabaseAdmin::Paths.database_path(
              project: project, instance: instance_id, database: database_id
            ),
            labels: labels
          )
          Session.from_grpc grpc, @service
        end
      end

      class Session
        def commit_transaction transaction, mutations = []
          ensure_service!

          resp = service.commit(
            path,
            mutations,
            transaction_id: transaction.transaction_id
          )
          @last_updated_at = Time.now
          Convert.timestamp_to_time resp.commit_timestamp
        end

        def create_snapshot strong: nil,
                     timestamp: nil, read_timestamp: nil,
                     staleness: nil, exact_staleness: nil
          validate_snapshot_args! strong: strong, timestamp: timestamp,
                                  read_timestamp: read_timestamp,
                                  staleness: staleness,
                                  exact_staleness: exact_staleness
          ensure_service!

          snp_grpc = service.create_snapshot \
            path, timestamp: (timestamp || read_timestamp),
            staleness: (staleness || exact_staleness)
          Snapshot.from_grpc snp_grpc, self
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
