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

        # Create a single-use transaction selector.
        def self.single_use_transaction opts
          return nil if opts.nil? || opts.empty?

          exact_timestamp = Convert.time_to_timestamp opts[:read_timestamp]
          exact_staleness = Convert.number_to_duration opts[:exact_staleness]
          min_read_timestamp = Convert.time_to_timestamp opts[:min_read_timestamp]
          max_staleness = Convert.number_to_duration opts[:max_staleness]

          V1::TransactionSelector.new(single_use:
            V1::TransactionOptions.new(read_only:
              V1::TransactionOptions::ReadOnly.new({
                strong: opts[:strong],
                read_timestamp: exact_timestamp,
                exact_staleness: exact_staleness,
                min_read_timestamp: min_read_timestamp,
                max_staleness: max_staleness,
                return_read_timestamp: true
              }.delete_if { |_, v| v.nil? })))
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
          num_args = Snapshot.method(:from_grpc).arity
          if num_args == 3
            Snapshot.from_grpc snp_grpc, self, nil
          else
            Snapshot.from_grpc snp_grpc, self
          end
        end

        def create_pdml
          ensure_service!
          pdml_grpc = service.create_pdml path
          Transaction.from_grpc pdml_grpc, self
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

      class Results
        attr_reader :metadata
      end

      class Transaction
        attr_accessor :seqno, :commit
      end
    end
  end
end
