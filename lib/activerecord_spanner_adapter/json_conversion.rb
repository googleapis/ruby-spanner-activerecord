require "google/cloud/spanner"
require "activerecord_spanner_adapter/json_encoder"

module ActiveRecordSpannerAdapter
  module JsonConversion
    def object_to_grpc_value obj, field = nil
      return super if obj.respond_to?(:to_column_value) || obj.respond_to?(:to_grpc_value_and_type)

      # Mutation rows have no field metadata; query STRUCTs must keep their native encoding.
      if obj.is_a?(Hash) && !field.is_a?(Google::Cloud::Spanner::Fields)
        obj = JsonEncoder.new.encode obj
      end
      super obj, field
    end
  end
end

Google::Cloud::Spanner::Convert.singleton_class.prepend ActiveRecordSpannerAdapter::JsonConversion
