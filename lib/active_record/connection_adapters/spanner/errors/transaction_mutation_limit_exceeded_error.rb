# Copyright 2025 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

module Google
  module Cloud
    module Spanner
      module Errors
        # Custom exception raised when a transaction exceeds the mutation limit in Google Cloud Spanner.
        # This provides a specific error class for a common, recoverable scenario.
        class TransactionMutationLimitExceededError < ActiveRecord::StatementInvalid
          ERROR_MESSAGE = "The transaction contains too many mutations".freeze

          def self.is_mutation_limit_error? error
            return false if error.nil?
            error.is_a?(Google::Cloud::InvalidArgumentError) &&
              error.message&.include?(ERROR_MESSAGE)
          end
        end
      end
    end
  end
end
