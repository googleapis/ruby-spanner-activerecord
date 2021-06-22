module ActiveRecord
  module AttributeMethods
    module PrimaryKey
      module ClassMethods
        def primary_and_parent_key
          reset_primary_and_parent_key unless defined? @primary_and_parent_key
          @primary_and_parent_key
        end

        def reset_primary_and_parent_key
          if base_class?
            self.primary_and_parent_key = get_primary_and_parent_key
          else
            self.primary_and_parent_key = base_class.primary_and_parent_key
          end
        end

        def get_primary_and_parent_key
          if ActiveRecord::Base != self && table_exists?
            connection.schema_cache.primary_and_parent_keys table_name
          end
        end

        def primary_and_parent_key= value
          @primary_and_parent_key = value
        end
      end
    end
  end
end
