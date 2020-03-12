module ActiveRecord
  module ConnectionAdapters #:nodoc:
    module Spanner
      class ReferenceDefinition < ActiveRecord::ConnectionAdapters::ReferenceDefinition
        def initialize \
            name,
            polymorphic: false,
            index: true,
            foreign_key: false,
            type: :string,
            **options
          @name = name
          @polymorphic = polymorphic
          @index = index
          @foreign_key = foreign_key
          @type = type
          @options = options
          @options[:limit] ||= 36
        end

        private

        def columns
          result = [[column_name, type, options]]
          if polymorphic
            type_options = polymorphic_options.merge limit: 255
            result.unshift ["#{name}_type", :string, type_options]
          end
          result
        end
      end

      class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
        def references *args, **options
          args.each do |ref_name|
            ReferenceDefinition.new(ref_name, options).add_to(self)
          end
        end
        alias belongs_to references
      end
    end
  end
end
