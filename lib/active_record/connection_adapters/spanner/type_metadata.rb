# The MIT License (MIT)
#
# Copyright (c) 2020 Google LLC.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# ITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Spanner
      class TypeMetadata < DelegateClass(SqlTypeMetadata)
        undef to_yaml if method_defined? :to_yaml

        attr_reader :ordinal_position

        def initialize type_metadata, ordinal_position: nil
          super type_metadata
          @ordinal_position = ordinal_position
        end

        def == other
          other.is_a?(TypeMetadata) &&
            __getobj__ == other.__getobj__ &&
            ordinal_position == other.ordinal_position
        end
        alias eql? ==

        def hash
          TypeMetadata.hash ^
            __getobj__.hash ^
            ordinal_position.hash
        end
      end
    end
  end
end
