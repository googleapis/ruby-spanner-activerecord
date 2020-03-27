require "activerecord_spanner_adapter/version"
require "activerecord_spanner_adapter/errors"
require "active_record/connection_adapters/spanner_adapter"
require "active_record/tasks/spanner_database_tasks"
require "google/cloud/spanner"
require "spanner_client_ext"
require "activerecord_spanner_adapter/information_schema"

module ActiveRecordSpannerAdapter
  ActiveRecord::Tasks::DatabaseTasks.register_task(
    /spanner/,
    "ActiveRecord::Tasks::SpannerDatabaseTasks"
  )
end
