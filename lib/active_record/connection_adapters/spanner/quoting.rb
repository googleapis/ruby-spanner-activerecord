# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Spanner
      module Quoting
        extend ActiveSupport::Concern

        QUOTED_COLUMN_NAMES = Concurrent::Map.new # :nodoc:
        QUOTED_TABLE_NAMES = Concurrent::Map.new # :nodoc:

        NAMED_CONTROL_CHAR_ESCAPES = {
          "\a" => "\\a",
          "\b" => "\\b",
          "\f" => "\\f",
          "\n" => "\\n",
          "\r" => "\\r",
          "\t" => "\\t",
          "\v" => "\\v"
        }.freeze

        CONTROL_CHAR_ESCAPES = ((0x00..0x1f).to_a << 0x7f).each_with_object({}) do |code, map|
          char = code.chr(Encoding::UTF_8).freeze
          map[char] = (NAMED_CONTROL_CHAR_ESCAPES[char] || format("\\x%02x", code)).freeze
        end.freeze

        IDENT_ESCAPE_REGX = /[\x00-\x1f\x7f\\`]/
        IDENT_ESCAPE_VALUES = CONTROL_CHAR_ESCAPES.merge("\\" => "\\\\", "`" => "\\`").freeze

        STR_ESCAPE_REGX = /[\x00-\x1f\x7f'\\]/
        STR_ESCAPE_VALUES = CONTROL_CHAR_ESCAPES.merge("'" => "\\'", "\\" => "\\\\").freeze

        BYTES_ESCAPE_REGX = /[^\x20-\x26\x28-\x5b\x5d-\x7e]/n
        BYTES_ESCAPE_VALUES = (0x80..0xff).each_with_object(
          STR_ESCAPE_VALUES.transform_keys { |k| k.b.freeze }
        ) do |byte, map|
          map[byte.chr(Encoding::BINARY).freeze] = format("\\x%02x", byte).freeze
        end.freeze

        private_constant :NAMED_CONTROL_CHAR_ESCAPES, :CONTROL_CHAR_ESCAPES,
                         :IDENT_ESCAPE_REGX, :IDENT_ESCAPE_VALUES,
                         :STR_ESCAPE_REGX, :STR_ESCAPE_VALUES,
                         :BYTES_ESCAPE_REGX, :BYTES_ESCAPE_VALUES

        def self.escape_identifier name
          name.to_s.gsub IDENT_ESCAPE_REGX, IDENT_ESCAPE_VALUES
        end

        def self.quote_column_name name
          QUOTED_COLUMN_NAMES[name] || QUOTED_COLUMN_NAMES.compute_if_absent(name) do
            "`#{escape_identifier name}`".freeze
          end
        end

        def self.quote_table_name name
          QUOTED_TABLE_NAMES[name] || QUOTED_TABLE_NAMES.compute_if_absent(name) do
            name_string = name.to_s
            next "`#{escape_identifier name_string}`".freeze unless name_string.include? "."

            name_string.split(".", -1).map do |part|
              "`#{escape_identifier part}`"
            end.join(".").freeze
          end
        end

        module ClassMethods # :nodoc:
          # This is used for ActiveRecord v8 and higher.
          delegate :quote_column_name, :quote_table_name, to: Spanner::Quoting
        end

        delegate :quote_column_name, :quote_table_name, to: Spanner::Quoting

        def quote_string s
          s.gsub STR_ESCAPE_REGX, STR_ESCAPE_VALUES
        end

        def quoted_binary value
          raw = value.to_s
          raw = raw.b unless raw.encoding == Encoding::BINARY
          escaped = raw.gsub BYTES_ESCAPE_REGX, BYTES_ESCAPE_VALUES
          "b'#{escaped}'".force_encoding Encoding::UTF_8
        end

        def _type_cast value
          case value
          when Array
            ActiveSupport::JSON.encode value
          else
            super
          end
        end
      end
    end
  end
end
