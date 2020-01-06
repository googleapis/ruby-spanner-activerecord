# frozen_string_literal: true

# NOTE: Not required as of now

module ActiveRecord
  module ConnectionAdapters
    module Spanner
      class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
      end
    end
  end
end
