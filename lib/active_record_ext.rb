module ActiveRecord
  module Tasks
    extend ActiveSupport::Autoload

    autoload :SpannerDatabaseTasks, "active_record/tasks/spanner_database_tasks"

    # Register tasks
    DatabaseTasks.register_task(
      /spanner/,
      "ActiveRecord::Tasks::SpannerDatabaseTasks"
    )
  end
end
