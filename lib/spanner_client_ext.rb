# TODO: Remove this file after spanner client provide access
# to session pool and reset
module Google
  module Cloud
    module Spanner
      class Client
        attr_reader :pool

        def reset
          @pool.reset
          # issue in google/spanner. Need to set @closed value to false on
          # pool init
          @pool.instance_variable_set "@closed", false
          true
        end
      end
    end
  end
end
