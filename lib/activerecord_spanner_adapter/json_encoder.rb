require "active_support"
require "active_support/json"
require "activerecord_spanner_adapter/float_formatter"

module ActiveRecordSpannerAdapter
  class JsonEncoder < ActiveSupport::JSON::Encoding::JSONGemEncoder
    private

    def jsonify value
      if value.is_a?(Float) && value.finite?
        # Spanner checks decimal round trips using nlohmann/json's float formatter.
        ::JSON::Fragment.new FloatFormatter.serialize_float(value)
      else
        super
      end
    end
  end
end
