require "spanner_activerecord/version"
require "spanner_activerecord/errors"
require "active_record/connection_adapters/spanner_adapter"
require "active_record_ext"
require "google/cloud/spanner"
require "spanner_client_ext"

module SpannerActiverecord
  extend ActiveSupport::Autoload

  autoload :InformationSchema, "spanner_activerecord/information_schema"
  autoload :Database, "spanner_activerecord/database"
  autoload :Table, "spanner_activerecord/table"
  autoload :Column, "spanner_activerecord/column"
  autoload :Index, "spanner_activerecord/index"
end
