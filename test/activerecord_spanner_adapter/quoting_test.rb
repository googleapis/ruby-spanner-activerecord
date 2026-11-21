# Copyright 2026 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"

class QuotingTest < TestHelper::MockActiveRecordTest
  def setup
    super
    @adapter = ActiveRecord::ConnectionAdapters::SpannerAdapter.new(
      connection, nil, nil, { project: project_id, instance: instance_id, database: database_id }
    )
  end

  def test_quote_and_quote_string_use_googlesql_backslash_escaping
    assert_equal "hello", @adapter.quote_string("hello")
    assert_equal "it\\'s", @adapter.quote_string("it's")
    assert_equal "a\\\\\\'b", @adapter.quote_string("a\\'b")
    assert_equal "line1\\nline2\\r\\x00", @adapter.quote_string("line1\nline2\r\0")
    assert_equal "\\'\\'\\'", @adapter.quote_string("'''")
    assert_equal "say \"hi\"", @adapter.quote_string('say "hi"')

    assert_equal "'a\\\\\\'b\\n'", @adapter.quote("a\\'b\n")
    assert_equal "'say \"hi\"'", @adapter.quote('say "hi"')
    assert_equal "'sym_\\'\\\\'", @adapter.quote(:"sym_'\\")
  end

  def test_quote_column_name_uses_googlesql_backslash_escaping
    assert_equal "`name`", @adapter.quote_column_name("name")
    assert_equal "`name`", @adapter.quote_column_name(:name)
    assert_equal "``", @adapter.quote_column_name("")
    assert_equal "``", @adapter.quote_column_name(nil)
    assert_equal "`col\\`name`", @adapter.quote_column_name("col`name")
    assert_equal "`col\\`name`", @adapter.quote_column_name(:"col`name")
    assert_equal "`col\\\\`", @adapter.quote_column_name("col\\")
    assert_equal "`col\\\\\\`name`", @adapter.quote_column_name("col\\`name")
    assert_equal "`col\\n\\r\\t\\x00`", @adapter.quote_column_name("col\n\r\t\0")
  end

  def test_quote_table_name_escapes_backticks_backslashes_and_edge_cases
    assert_equal "`users`", @adapter.quote_table_name("users")
    assert_equal "`users`", @adapter.quote_table_name(:users)
    assert_equal "``", @adapter.quote_table_name("")
    assert_equal "``", @adapter.quote_table_name(nil)
    assert_equal "`a`.``", @adapter.quote_table_name("a.")
    assert_equal "``.`b`", @adapter.quote_table_name(".b")
    assert_equal "`a`.`b`.`c`", @adapter.quote_table_name("a.b.c")
    assert_equal "`a`.``.`b`", @adapter.quote_table_name("a..b")
    assert_equal "`my_schema`.`users`", @adapter.quote_table_name("my_schema.users")
    assert_equal "`sch\\`1`.`tbl\\`2`", @adapter.quote_table_name(:"sch`1.tbl`2")
    assert_equal "`users\\` WHERE 1=1 --`", @adapter.quote_table_name("users` WHERE 1=1 --")
    assert_equal "`users\\\\`", @adapter.quote_table_name("users\\")
    assert_equal "`sch\\`ema`.`tab\\`le`", @adapter.quote_table_name("sch`ema.tab`le")
    assert_equal "`sch\\n1`.`tbl\\x002`", @adapter.quote_table_name("sch\n1.tbl\x002")
    assert_equal "`tbl\\`1`.`col\\`2`", @adapter.quote_table_name_for_assignment("tbl`1", "col`2")
  end

  def test_identifier_cache_returns_same_frozen_string
    col1 = @adapter.quote_column_name "cached_col"
    col2 = @adapter.quote_column_name "cached_col"
    assert_predicate col1, :frozen?
    assert_same col1, col2

    tbl1 = @adapter.quote_table_name "cached_tbl"
    tbl2 = @adapter.quote_table_name "cached_tbl"
    assert_predicate tbl1, :frozen?
    assert_same tbl1, tbl2

    dotted1 = @adapter.quote_table_name "cached_schema.cached_tbl"
    dotted2 = @adapter.quote_table_name "cached_schema.cached_tbl"
    assert_predicate dotted1, :frozen?
    assert_same dotted1, dotted2
  end

  def test_class_methods_quote_identifiers_without_polluting_base_quoting
    assert_equal "`col\\`1`", ActiveRecord::ConnectionAdapters::SpannerAdapter.quote_column_name("col`1")
    assert_equal "`sch`.`tbl\\`1`", ActiveRecord::ConnectionAdapters::SpannerAdapter.quote_table_name("sch.tbl`1")

    # Verify ActiveRecord::ConnectionAdapters::Quoting::ClassMethods was not overwritten globally.
    other_adapter_class = Class.new do
      include ActiveRecord::ConnectionAdapters::Quoting
    end
    if other_adapter_class.respond_to? :quote_column_name
      assert_raises NotImplementedError do
        other_adapter_class.quote_column_name "col"
      end
    else
      refute_respond_to other_adapter_class, :quote_column_name
    end
  end

  def test_quoted_binary_escapes_quotes_backslashes_and_control_bytes
    assert_equal "b'hello'", @adapter.quoted_binary("hello")
    assert_equal "b''", @adapter.quoted_binary(nil)
    assert_equal "b'Caf\\xc3\\xa9\\xf0\\x9f\\x8e\\xb5'", @adapter.quoted_binary("Café🎵")
    assert_equal "b'a\\'b\\\\c\\nd\\re\\tf\\ag'", @adapter.quoted_binary("a'b\\c\nd\re\tf\ag")
    assert_equal "b'\\'; DROP TABLE users; --'", @adapter.quoted_binary("'; DROP TABLE users; --")

    raw_bytes = ActiveModel::Type::Binary::Data.new("\x00\x01\x89PNG\r\n\x1a\n\xff".b)
    quoted = @adapter.quote raw_bytes
    assert_equal Encoding::UTF_8, quoted.encoding
    assert_equal "b'\\x00\\x01\\x89PNG\\r\\n\\x1a\\n\\xff'", quoted

    (0x80..0xff).each do |byte|
      encoded = @adapter.quoted_binary byte.chr(Encoding::BINARY)
      assert_equal Encoding::UTF_8, encoded.encoding
      assert_equal format("b'\\x%02x'", byte), encoded
    end
  end

  def test_all_ascii_control_characters_and_utf8_preserved
    expected_control_escapes = {
      0x00 => "\\x00", 0x01 => "\\x01", 0x02 => "\\x02", 0x03 => "\\x03",
      0x04 => "\\x04", 0x05 => "\\x05", 0x06 => "\\x06", 0x07 => "\\a",
      0x08 => "\\b",   0x09 => "\\t",   0x0a => "\\n",   0x0b => "\\v",
      0x0c => "\\f",   0x0d => "\\r",   0x0e => "\\x0e", 0x0f => "\\x0f",
      0x10 => "\\x10", 0x11 => "\\x11", 0x12 => "\\x12", 0x13 => "\\x13",
      0x14 => "\\x14", 0x15 => "\\x15", 0x16 => "\\x16", 0x17 => "\\x17",
      0x18 => "\\x18", 0x19 => "\\x19", 0x1a => "\\x1a", 0x1b => "\\x1b",
      0x1c => "\\x1c", 0x1d => "\\x1d", 0x1e => "\\x1e", 0x1f => "\\x1f",
      0x7f => "\\x7f"
    }

    expected_control_escapes.each do |code, expected|
      char = code.chr Encoding::UTF_8
      assert_equal "`col#{expected}name`", @adapter.quote_column_name("col#{char}name")
      assert_equal "val#{expected}str", @adapter.quote_string("val#{char}str")
      assert_equal "b'val#{expected}bin'", @adapter.quoted_binary("val#{char}bin")
    end

    assert_equal "`Café\\`\\\\🎵`", @adapter.quote_column_name("Café`\\🎵")
    assert_equal "Café\\'\\\\🎵", @adapter.quote_string("Café'\\🎵")
  end
end
