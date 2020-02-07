module ActiveRecord
  module ConnectionAdapters #:nodoc:
    class ReferenceDefinition # :nodoc:
      def initialize \
          name,
          polymorphic: false,
          index: true,
          type: :string,
          **options
        @name = name
        @polymorphic = polymorphic
        @index = index
        @foreign_key = false
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
  end
end
