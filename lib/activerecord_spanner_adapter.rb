require "activerecord_spanner_adapter/version"
require "activerecord_spanner_adapter/errors"
require "active_record/connection_adapters/spanner_adapter"
require "active_record_ext"
require "google/cloud/spanner"
require "spanner_client_ext"

module ActiveRecordSpannerAdapter
  extend ActiveSupport::Autoload

  autoload :InformationSchema, "activerecord_spanner_adapter/information_schema"
  autoload :Database, "activerecord_spanner_adapter/database"
  autoload :Table, "activerecord_spanner_adapter/table"
  autoload :Column, "activerecord_spanner_adapter/column"
  autoload :Index, "activerecord_spanner_adapter/index"
  autoload :ForeignKey, "activerecord_spanner_adapter/foreign_key"
end
