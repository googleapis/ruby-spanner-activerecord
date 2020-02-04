# TODO: Remove this file after spanner client provided extanded
# functionalities

module Google
  module Cloud
    module Spanner
      class Project
        def create_session instance_id, database_id, labels: nil
          grpc = @service.create_session(
            database_path(instance_id, database_id),
            labels: labels
          )
          Session.from_grpc grpc, @service
        end
      end

      class Session
        def commit_transaction transaction_id
          @service.commit path, transaction_id: transaction_id
          @last_updated_at = Time.now
        end

        def begin_transaction
          @service.begin_transaction path
        end
      end
    end
  end
end
