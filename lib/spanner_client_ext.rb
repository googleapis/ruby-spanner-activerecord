# TODO: Remove this file after spanner client provide access to session pool and reset
module Google
  module Cloud
    module Spanner
      class Client
        attr_reader :pool

        def reset
          @pool.reset
        end
      end
    end
  end
end
