# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "active_record/connection_adapters/abstract/quoting"
require "activerecord_spanner_adapter/information_schema"
require "activerecord_spanner_adapter/table"
require "activerecord_spanner_adapter/index"
require "activerecord_spanner_adapter/foreign_key"


module ActiveRecordSpannerAdapter
  class InformationSchema
    include ActiveRecord::ConnectionAdapters::Quoting

    attr_reader :connection

    def initialize connection
      @connection = connection
      @mutex = Mutex.new
    end

    def tables table_name: nil, schema_name: nil, view: nil
      sql = +"SELECT TABLE_CATALOG, TABLE_SCHEMA, TABLE_NAME, PARENT_TABLE_NAME, ON_DELETE_ACTION"
      sql << " FROM INFORMATION_SCHEMA.TABLES"
      sql << " WHERE TABLE_SCHEMA=%<schema_name>s"
      sql << " AND TABLE_NAME=%<table_name>s" if table_name

      rows = execute_query(
        sql,
        schema_name: (schema_name || ""), table_name: table_name
      )

      rows.map do |row|
        table = Table.new(
          row["TABLE_NAME"],
          parent_table: row["PARENT_TABLE_NAME"],
          on_delete: row["ON_DELETE_ACTION"],
          schema_name: row["TABLE_SCHEMA"],
          catalog: row["TABLE_CATALOG"]
        )

        if [:full, :columns].include? view
          table.columns = table_columns table.name
        end

        if [:full, :indexes].include? view
          table.indexes = indexes table.name
        end
        table
      end
    end

    def table table_name, schema_name: nil, view: nil
      tables(
        table_name: table_name,
        schema_name: schema_name,
        view: view
      ).first
    end

    def table_columns table_name, column_name: nil
      sql = +"SELECT COLUMN_NAME, SPANNER_TYPE, IS_NULLABLE,"
      sql << " CAST(COLUMN_DEFAULT AS STRING) AS COLUMN_DEFAULT, ORDINAL_POSITION"
      sql << " FROM INFORMATION_SCHEMA.COLUMNS"
      sql << " WHERE TABLE_NAME=%<table_name>s"
      sql << " AND COLUMN_NAME=%<column_name>s" if column_name
      sql << " ORDER BY ORDINAL_POSITION ASC"

      column_options = column_options table_name, column_name
      execute_query(
        sql,
        table_name: table_name,
        column_name: column_name
      ).map do |row|
        type, limit = parse_type_and_limit row["SPANNER_TYPE"]
        column_name = row["COLUMN_NAME"]
        options = column_options[column_name]

        Table::Column.new \
          table_name,
          column_name,
          type,
          limit: limit,
          allow_commit_timestamp: options["allow_commit_timestamp"],
          ordinal_position: row["ORDINAL_POSITION"],
          nullable: row["IS_NULLABLE"] == "YES",
          default: row["COLUMN_DEFAULT"]
      end
    end

    def table_column table_name, column_name
      table_columns(table_name, column_name: column_name).first
    end

    # Returns the primary key columns of the given table. By default it will only return the columns that are not part
    # of the primary key of the parent table (if any). These are the columns that are considered the primary key by
    # ActiveRecord. The parent primary key columns are filtered out by default to allow interleaved tables to be
    # considered as tables with a single-column primary key by ActiveRecord. The actual primary key of the table will
    # include both the parent primary key columns and the 'own' primary key columns of a table.
    def table_primary_keys table_name, include_parent_keys = false
      sql = +"WITH TABLE_PK_COLS AS ( "
      sql << "SELECT C.TABLE_NAME, C.COLUMN_NAME, C.INDEX_NAME, C.COLUMN_ORDERING, C.ORDINAL_POSITION "
      sql << "FROM INFORMATION_SCHEMA.INDEX_COLUMNS C "
      sql << "WHERE C.INDEX_TYPE = 'PRIMARY_KEY' "
      sql << "AND TABLE_CATALOG = '' "
      sql << "AND TABLE_SCHEMA = '') "
      sql << "SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION "
      sql << "FROM TABLE_PK_COLS "
      sql << "INNER JOIN INFORMATION_SCHEMA.TABLES T USING (TABLE_NAME) "
      sql << "WHERE TABLE_NAME = %<table_name>s "
      sql << "AND TABLE_CATALOG = '' "
      sql << "AND TABLE_SCHEMA = '' "
      unless include_parent_keys
        sql << "AND (T.PARENT_TABLE_NAME IS NULL OR COLUMN_NAME NOT IN ( "
        sql << "  SELECT COLUMN_NAME "
        sql << "  FROM TABLE_PK_COLS "
        sql << "  WHERE TABLE_NAME = T.PARENT_TABLE_NAME "
        sql << ")) "
      end
      sql << "ORDER BY ORDINAL_POSITION"
      execute_query(
        sql,
        table_name: table_name
      ).map do |row|
        Index::Column.new \
          table_name,
          row["INDEX_NAME"],
          row["COLUMN_NAME"],
          order: row["COLUMN_ORDERING"],
          ordinal_position: row["ORDINAL_POSITION"]
      end
    end

    def indexes table_name, index_name: nil, index_type: nil
      table_indexes_columns = index_columns(
        table_name,
        index_name: index_name
      )

      sql = +"SELECT INDEX_NAME, INDEX_TYPE, IS_UNIQUE, IS_NULL_FILTERED, PARENT_TABLE_NAME, INDEX_STATE"
      sql << " FROM INFORMATION_SCHEMA.INDEXES"
      sql << " WHERE TABLE_NAME=%<table_name>s"
      sql << " AND TABLE_CATALOG = ''"
      sql << " AND TABLE_SCHEMA = ''"
      sql << " AND INDEX_NAME=%<index_name>s" if index_name
      sql << " AND INDEX_TYPE=%<index_type>s" if index_type
      sql << " AND SPANNER_IS_MANAGED=FALSE"

      execute_query(
        sql,
        table_name: table_name,
        index_name: index_name,
        index_type: index_type
      ).map do |row|
        columns = []
        storing = []
        table_indexes_columns.each do |c|
          next unless c.index_name == row["INDEX_NAME"]
          if c.ordinal_position
            columns << c
          else
            storing << c.name
          end
        end

        Index.new \
          table_name,
          row["INDEX_NAME"],
          columns,
          type: row["INDEX_TYPE"],
          unique: row["IS_UNIQUE"],
          null_filtered: row["IS_NULL_FILTERED"],
          interleave_in: row["PARENT_TABLE_NAME"],
          storing: storing,
          state: row["INDEX_STATE"]
      end
    end

    def index table_name, index_name
      indexes(table_name, index_name: index_name).first
    end

    def index_columns table_name, index_name: nil
      sql = +"SELECT INDEX_NAME, COLUMN_NAME, COLUMN_ORDERING, ORDINAL_POSITION"
      sql << " FROM INFORMATION_SCHEMA.INDEX_COLUMNS"
      sql << " WHERE TABLE_NAME=%<table_name>s"
      sql << " AND TABLE_CATALOG = ''"
      sql << " AND TABLE_SCHEMA = ''"
      sql << " AND INDEX_NAME=%<index_name>s" if index_name
      sql << " ORDER BY ORDINAL_POSITION ASC"

      execute_query(
        sql,
        table_name: table_name, index_name: index_name
      ).map do |row|
        Index::Column.new \
          table_name,
          row["INDEX_NAME"],
          row["COLUMN_NAME"],
          order: row["COLUMN_ORDERING"],
          ordinal_position: row["ORDINAL_POSITION"]
      end
    end

    def indexes_by_columns table_name, column_names
      column_names = Array(column_names).map(&:to_s)

      indexes(table_name).select do |index|
        index.columns.any? { |c| column_names.include? c.name }
      end
    end

    def foreign_keys table_name
      sql = <<~SQL
        SELECT cc.table_name AS to_table,
               cc.column_name AS primary_key,
               fk.column_name as column,
               fk.constraint_name AS name,
               rc.update_rule AS on_update,
               rc.delete_rule AS on_delete
        FROM information_schema.referential_constraints rc
        INNER JOIN information_schema.key_column_usage fk ON rc.constraint_name = fk.constraint_name
        INNER JOIN information_schema.constraint_column_usage cc ON rc.constraint_name = cc.constraint_name
        WHERE fk.table_name = %<table_name>s
          AND fk.constraint_schema = %<constraint_schema>s
      SQL

      rows = execute_query(
        sql, table_name: table_name, constraint_schema: ""
      )

      rows.map do |row|
        ForeignKey.new(
          table_name,
          row["name"],
          row["column"],
          row["to_table"],
          row["primary_key"],
          on_delete: row["on_delete"],
          on_update: row["on_update"]
        )
      end
    end

    def parse_type_and_limit value
      matched = /^([A-Z]*)\((.*)\)/.match value
      return [value] unless matched

      limit = matched[2]
      limit = limit.to_i unless limit == "MAX"

      [matched[1], limit]
    end

    private

    def column_options table_name, column_name
      sql = +"SELECT COLUMN_NAME, OPTION_NAME, OPTION_TYPE, OPTION_VALUE"
      sql << " FROM INFORMATION_SCHEMA.COLUMN_OPTIONS"
      sql << " WHERE TABLE_NAME=%<table_name>s"
      sql << " AND COLUMN_NAME=%<column_name>s" if column_name

      column_options = Hash.new { |h, k| h[k] = {} }
      execute_query(
        sql,
        table_name: table_name,
        column_name: column_name
      ).each_with_object(column_options) do |row, options|
        next unless row["OPTION_TYPE"] == "BOOL"

        col = row["COLUMN_NAME"]
        opt = row["OPTION_NAME"]
        value = row["OPTION_VALUE"] == "TRUE"
        options[col][opt] = value
      end
    end

    def execute_query sql, params = {}
      params = params.transform_values { |v| quote v }
      sql = format sql, params

      @connection.execute_query(sql).rows
    end
  end
end
