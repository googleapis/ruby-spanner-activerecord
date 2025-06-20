module Google
  module Cloud
    module Spanner
      module Errors
        # Custom exception raised when a transaction exceeds the mutation limit in Google Cloud Spanner.
        # This provides a specific error class for a common, recoverable scenario.
        class TransactionMutationLimitExceededError < Google::Cloud::Error
          ERROR_MESSAGE = "The transaction contains too many mutations".freeze

          def self.is_mutation_limit_error? exception
            return false if exception.message.nil?
            cause = exception.cause
            return false unless cause.is_a? GRPC::InvalidArgument
            cause.details.include?(ERROR_MESSAGE) || exception.message.include?(ERROR_MESSAGE)
          end
        end
      end
    end
  end
end
