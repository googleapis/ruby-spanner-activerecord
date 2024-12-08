# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "activerecord_spanner_adapter/version"

if defined?(Rails)
  module ActiveRecord
    module ConnectionAdapters
      class SpannerRailtie < ::Rails::Railtie
        rake_tasks do
          require "active_record/tasks/spanner_database_tasks"
        end

        ActiveSupport.on_load :active_record do
          if Rails.version >= '7.2.0'
            ActiveRecord::ConnectionAdapters.register("spanner", "ActiveRecord::ConnectionAdapters::SpannerAdapter")
          else
            require "active_record/connection_adapters/spanner_adapter"
          end
        end
      end
    end
  end
end
