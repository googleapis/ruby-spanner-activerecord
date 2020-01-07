require "spanner_activerecord/version"
require "spanner_activerecord/error"
require "active_record/connection_adapters/spanner_adapter"
require "active_record_ext"

module SpannerActiverecord
  extend ActiveSupport::Autoload

  autoload :InformationSchema
  autoload :Database
  autoload :Table
  autoload :Column
  autoload :Index
end
