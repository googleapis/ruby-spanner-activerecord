require "activerecord_spanner_adapter/version"

if defined?(Rails)
  module ActiveRecord
    module ConnectionAdapters
      class SpannerRailtie < ::Rails::Railtie
        rake_tasks do
          require "active_record/tasks/spanner_database_tasks"
        end

        ActiveSupport.on_load :active_record do
          require "active_record/connection_adapters/spanner_adapter"
        end
      end
    end
  end
end
