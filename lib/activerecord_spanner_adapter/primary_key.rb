# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

module ActiveRecord
  module AttributeMethods
    module PrimaryKey
      module ClassMethods
        def primary_and_parent_key
          reset_primary_and_parent_key unless defined? @primary_and_parent_key
          @primary_and_parent_key
        end

        def reset_primary_and_parent_key
          self.primary_and_parent_key = base_class? ? fetch_primary_and_parent_key : base_class.primary_and_parent_key
        end

        def fetch_primary_and_parent_key
          return connection.spanner_schema_cache.primary_and_parent_keys table_name \
            if ActiveRecord::Base != self && table_exists?
        end

        def primary_and_parent_key= value
          @primary_and_parent_key = value
        end
      end
    end
  end
end
