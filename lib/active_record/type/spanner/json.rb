require "active_record/type/json"
require "activerecord_spanner_adapter/json_encoder"

module ActiveRecord
  module Type
    module Spanner
      class Json < Type::Json
        def serialize value
          return if value.nil?

          options = { escape: false } if ActiveSupport::JSON::Encoding.respond_to? :encode_without_escape
          ActiveRecordSpannerAdapter::JsonEncoder.new(options).encode value
        end
      end
    end
  end
end

ActiveRecord::Type.register :json, ActiveRecord::Type::Spanner::Json, adapter: :spanner
