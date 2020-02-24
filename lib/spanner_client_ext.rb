# TODO: Remove this file after spanner client provided extanded
# functionalities

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
      end

      class Transaction
        attr_accessor :seqno, :commit
      end
    end
  end
end
