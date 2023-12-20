# Copyright 2022 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"
require "active_record/tasks/spanner_database_tasks"

module ActiveRecord
  module Tasks
    class DatabaseTasksTest < SpannerAdapter::TestCase
      attr_reader :connector_config, :connection

      def is_7_1_or_higher?
        ActiveRecord::gem_version >= Gem::Version.create('7.1.0')
      end

      def setup
        @database_id = "ar-tasks-test-#{SecureRandom.hex 4}"
        @connector_config = {
          "adapter" => "spanner",
          "emulator_host" => ENV["SPANNER_EMULATOR_HOST"],
          "project" => ENV["SPANNER_TEST_PROJECT"],
          "instance" => ENV["SPANNER_TEST_INSTANCE"],
          "credentials" => ENV["SPANNER_TEST_KEYFILE"],
          "database" => @database_id
        }

        create_database
        ActiveRecord::Base.establish_connection connector_config
        @connection = ActiveRecord::Base.connection

        begin
          @original_db_dir = ActiveRecord::Tasks::DatabaseTasks.db_dir
          @original_env = ActiveRecord::Tasks::DatabaseTasks.env
        rescue NameError
          # ignore `NameError: uninitialized constant primary::Rails`
        end

        db_dir = File.expand_path "./db", __dir__
        ActiveRecord::Tasks::DatabaseTasks.db_dir = db_dir
        FileUtils.mkdir db_dir

        ActiveRecord::Tasks::DatabaseTasks.env = "test"
      end

      def teardown
        ActiveRecord::Base.connection_pool.disconnect!
        FileUtils.rm_rf ActiveRecord::Tasks::DatabaseTasks.db_dir
        ActiveRecord::Tasks::DatabaseTasks.db_dir = @original_db_dir
        ActiveRecord::Tasks::DatabaseTasks.env = @original_env
      end

      def create_database
        job = spanner_instance.create_database @database_id
        job.wait_until_done!
        if job.error?
          raise "Error in creating database. Error code#{job.error.message}"
        end
      end

      def drop_database
        ActiveRecord::Base.connection_pool.disconnect!
        ActiveRecordSpannerAdapter::Connection.reset_information_schemas!
        spanner_instance.database(@database_id)&.drop
      end

      def test_structure_dump_and_load
        require_relative "../../schema/schema"
        create_tables_in_test_schema

        db_config =
          if ActiveRecord.version >= Gem::Version.new("6.1")
            ActiveRecord::DatabaseConfigurations::HashConfig.new "test",
                                                                 "primary",
                                                                 connector_config
          else
            connector_config
          end

        tables = connection.tables.sort
        config_name = "primary"
        config_name = db_config.name if db_config.respond_to?(:name)
        if ActiveRecord::Tasks::DatabaseTasks.respond_to?(:dump_filename)
          filename = ActiveRecord::Tasks::DatabaseTasks.dump_filename(config_name, :sql)
        elsif ActiveRecord::Tasks::DatabaseTasks.respond_to?(:schema_dump_path)
          filename = ActiveRecord::Tasks::DatabaseTasks.schema_dump_path(db_config, :sql)
        end
        ActiveRecord::Tasks::DatabaseTasks.dump_schema db_config, :sql
        sql = File.read(filename)
        if ENV["SPANNER_EMULATOR_HOST"] && is_7_1_or_higher?
          assert_equal expected_schema_sql_on_emulator_7_1, sql, msg = sql
        elsif ENV["SPANNER_EMULATOR_HOST"]
          assert_equal expected_schema_sql_on_emulator, sql, msg = sql
        elsif is_7_1_or_higher?
          assert_equal expected_schema_sql_on_production_7_1, sql, msg = sql
        else
          assert_equal expected_schema_sql_on_production, sql, msg = sql
        end
        drop_database
        create_database
        ActiveRecord::Tasks::DatabaseTasks.load_schema db_config, :sql
        assert_equal tables, connection.tables.sort
      end

      def expected_schema_sql_on_emulator
        "CREATE TABLE all_types (
  id INT64 NOT NULL,
  col_string STRING(MAX),
  col_int64 INT64,
  col_float64 FLOAT64,
  col_numeric NUMERIC,
  col_bool BOOL,
  col_bytes BYTES(MAX),
  col_date DATE,
  col_timestamp TIMESTAMP,
  col_json JSON,
  col_array_string ARRAY<STRING(MAX)>,
  col_array_int64 ARRAY<INT64>,
  col_array_float64 ARRAY<FLOAT64>,
  col_array_numeric ARRAY<NUMERIC>,
  col_array_bool ARRAY<BOOL>,
  col_array_bytes ARRAY<BYTES(MAX)>,
  col_array_date ARRAY<DATE>,
  col_array_timestamp ARRAY<TIMESTAMP>,
  col_array_json ARRAY<JSON>,
) PRIMARY KEY(id);
CREATE TABLE firms (
  id INT64 NOT NULL,
  name STRING(MAX),
  rating INT64,
  description STRING(MAX),
  account_id INT64,
) PRIMARY KEY(id);
CREATE INDEX index_firms_on_account_id ON firms(account_id);
CREATE TABLE customers (
  id INT64 NOT NULL,
  name STRING(MAX),
) PRIMARY KEY(id);
CREATE TABLE accounts (
  id INT64 NOT NULL,
  customer_id INT64,
  firm_id INT64,
  name STRING(MAX),
  credit_limit INT64,
  transactions_count INT64,
) PRIMARY KEY(id);
CREATE TABLE transactions (
  id INT64 NOT NULL,
  amount FLOAT64,
  account_id INT64,
) PRIMARY KEY(id);
CREATE TABLE departments (
  id INT64 NOT NULL,
  name STRING(MAX),
  resource_type STRING(255),
  resource_id INT64,
) PRIMARY KEY(id);
CREATE INDEX index_departments_on_resource ON departments(resource_type, resource_id);
CREATE TABLE member_types (
  id INT64 NOT NULL,
  name STRING(MAX),
) PRIMARY KEY(id);
CREATE TABLE members (
  id INT64 NOT NULL,
  name STRING(MAX),
  member_type_id INT64,
  admittable_type STRING(255),
  admittable_id INT64,
) PRIMARY KEY(id);
CREATE TABLE memberships (
  id INT64 NOT NULL,
  joined_on TIMESTAMP,
  club_id INT64,
  member_id INT64,
  favourite BOOL,
) PRIMARY KEY(id);
CREATE TABLE clubs (
  id INT64 NOT NULL,
  name STRING(MAX),
) PRIMARY KEY(id);
CREATE TABLE authors (
  id INT64 NOT NULL,
  name STRING(MAX) NOT NULL,
  registered_date DATE,
  organization_id INT64,
) PRIMARY KEY(id);
CREATE TABLE posts (
  id INT64 NOT NULL,
  title STRING(MAX),
  content STRING(MAX),
  author_id INT64,
  comments_count INT64,
  post_date DATE,
  published_time TIMESTAMP,
) PRIMARY KEY(id);
CREATE INDEX index_posts_on_author_id ON posts(author_id);
CREATE TABLE comments (
  id INT64 NOT NULL,
  comment STRING(MAX),
  post_id INT64,
  CONSTRAINT fk_rails_2fd19c0db7 FOREIGN KEY(post_id) REFERENCES posts(id),
) PRIMARY KEY(id);
CREATE TABLE addresses (
  id INT64 NOT NULL,
  line1 STRING(MAX),
  postal_code STRING(MAX),
  city STRING(MAX),
  author_id INT64,
) PRIMARY KEY(id);
CREATE TABLE organizations (
  id INT64 NOT NULL,
  name STRING(MAX),
  last_updated TIMESTAMP OPTIONS (
    allow_commit_timestamp = true
  ),
) PRIMARY KEY(id);
CREATE TABLE singers (
  singerid INT64 NOT NULL,
  first_name STRING(200),
  last_name STRING(MAX),
  tracks_count INT64,
  lock_version INT64,
  full_name STRING(MAX) AS (COALESCE(first_name || ' ', '') || last_name) STORED,
) PRIMARY KEY(singerid);
CREATE TABLE albums (
  albumid INT64 NOT NULL,
  singerid INT64 NOT NULL,
  title STRING(MAX),
  lock_version INT64,
) PRIMARY KEY(singerid, albumid),
  INTERLEAVE IN PARENT singers ON DELETE NO ACTION;
CREATE TABLE tracks (
  trackid INT64 NOT NULL,
  singerid INT64 NOT NULL,
  albumid INT64 NOT NULL,
  title STRING(MAX),
  duration NUMERIC,
  lock_version INT64,
) PRIMARY KEY(singerid, albumid, trackid),
  INTERLEAVE IN PARENT albums ON DELETE CASCADE;
CREATE NULL_FILTERED INDEX index_tracks_on_singerid_and_albumid_and_title ON tracks(singerid, albumid, title), INTERLEAVE IN albums;
CREATE TABLE table_with_sequence (
  id INT64 NOT NULL DEFAULT (FARM_FINGERPRINT(GENERATE_UUID())),
  name STRING(MAX) NOT NULL,
  age INT64 NOT NULL,
) PRIMARY KEY(id);
CREATE TABLE schema_migrations (
  version STRING(MAX) NOT NULL,
) PRIMARY KEY(version);
CREATE TABLE ar_internal_metadata (
  key STRING(MAX) NOT NULL,
  value STRING(MAX),
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
) PRIMARY KEY(key);
INSERT INTO `schema_migrations` (version) VALUES
('1');

"
      end

      def expected_schema_sql_on_emulator_7_1
        "CREATE TABLE all_types (
  id INT64 NOT NULL,
  col_string STRING(MAX),
  col_int64 INT64,
  col_float64 FLOAT64,
  col_numeric NUMERIC,
  col_bool BOOL,
  col_bytes BYTES(MAX),
  col_date DATE,
  col_timestamp TIMESTAMP,
  col_json JSON,
  col_array_string ARRAY<STRING(MAX)>,
  col_array_int64 ARRAY<INT64>,
  col_array_float64 ARRAY<FLOAT64>,
  col_array_numeric ARRAY<NUMERIC>,
  col_array_bool ARRAY<BOOL>,
  col_array_bytes ARRAY<BYTES(MAX)>,
  col_array_date ARRAY<DATE>,
  col_array_timestamp ARRAY<TIMESTAMP>,
  col_array_json ARRAY<JSON>,
) PRIMARY KEY(id);
CREATE TABLE firms (
  id INT64 NOT NULL,
  name STRING(MAX),
  rating INT64,
  description STRING(MAX),
  account_id INT64,
) PRIMARY KEY(id);
CREATE INDEX index_firms_on_account_id ON firms(account_id);
CREATE TABLE customers (
  id INT64 NOT NULL,
  name STRING(MAX),
) PRIMARY KEY(id);
CREATE TABLE accounts (
  id INT64 NOT NULL,
  customer_id INT64,
  firm_id INT64,
  name STRING(MAX),
  credit_limit INT64,
  transactions_count INT64,
) PRIMARY KEY(id);
CREATE TABLE transactions (
  id INT64 NOT NULL,
  amount FLOAT64,
  account_id INT64,
) PRIMARY KEY(id);
CREATE TABLE departments (
  id INT64 NOT NULL,
  name STRING(MAX),
  resource_type STRING(255),
  resource_id INT64,
) PRIMARY KEY(id);
CREATE INDEX index_departments_on_resource ON departments(resource_type, resource_id);
CREATE TABLE member_types (
  id INT64 NOT NULL,
  name STRING(MAX),
) PRIMARY KEY(id);
CREATE TABLE members (
  id INT64 NOT NULL,
  name STRING(MAX),
  member_type_id INT64,
  admittable_type STRING(255),
  admittable_id INT64,
) PRIMARY KEY(id);
CREATE TABLE memberships (
  id INT64 NOT NULL,
  joined_on TIMESTAMP,
  club_id INT64,
  member_id INT64,
  favourite BOOL,
) PRIMARY KEY(id);
CREATE TABLE clubs (
  id INT64 NOT NULL,
  name STRING(MAX),
) PRIMARY KEY(id);
CREATE TABLE authors (
  id INT64 NOT NULL,
  name STRING(MAX) NOT NULL,
  registered_date DATE,
  organization_id INT64,
) PRIMARY KEY(id);
CREATE TABLE posts (
  id INT64 NOT NULL,
  title STRING(MAX),
  content STRING(MAX),
  author_id INT64,
  comments_count INT64,
  post_date DATE,
  published_time TIMESTAMP,
) PRIMARY KEY(id);
CREATE INDEX index_posts_on_author_id ON posts(author_id);
CREATE TABLE comments (
  id INT64 NOT NULL,
  comment STRING(MAX),
  post_id INT64,
  CONSTRAINT fk_rails_2fd19c0db7 FOREIGN KEY(post_id) REFERENCES posts(id),
) PRIMARY KEY(id);
CREATE TABLE addresses (
  id INT64 NOT NULL,
  line1 STRING(MAX),
  postal_code STRING(MAX),
  city STRING(MAX),
  author_id INT64,
) PRIMARY KEY(id);
CREATE TABLE organizations (
  id INT64 NOT NULL,
  name STRING(MAX),
  last_updated TIMESTAMP OPTIONS (
    allow_commit_timestamp = true
  ),
) PRIMARY KEY(id);
CREATE TABLE singers (
  singerid INT64 NOT NULL,
  first_name STRING(200),
  last_name STRING(MAX),
  tracks_count INT64,
  lock_version INT64,
  full_name STRING(MAX) AS (COALESCE(first_name || ' ', '') || last_name) STORED,
) PRIMARY KEY(singerid);
CREATE TABLE albums (
  singerid INT64 NOT NULL,
  albumid INT64 NOT NULL,
  title STRING(MAX),
  lock_version INT64,
) PRIMARY KEY(singerid, albumid),
  INTERLEAVE IN PARENT singers ON DELETE NO ACTION;
CREATE TABLE tracks (
  singerid INT64 NOT NULL,
  albumid INT64 NOT NULL,
  trackid INT64 NOT NULL,
  title STRING(MAX),
  duration NUMERIC,
  lock_version INT64,
) PRIMARY KEY(singerid, albumid, trackid),
  INTERLEAVE IN PARENT albums ON DELETE CASCADE;
CREATE NULL_FILTERED INDEX index_tracks_on_singerid_and_albumid_and_title ON tracks(singerid, albumid, title), INTERLEAVE IN albums;
CREATE TABLE table_with_sequence (
  id INT64 NOT NULL DEFAULT (FARM_FINGERPRINT(GENERATE_UUID())),
  name STRING(MAX) NOT NULL,
  age INT64 NOT NULL,
) PRIMARY KEY(id);
CREATE TABLE schema_migrations (
  version STRING(MAX) NOT NULL,
) PRIMARY KEY(version);
CREATE TABLE ar_internal_metadata (
  key STRING(MAX) NOT NULL,
  value STRING(MAX),
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
) PRIMARY KEY(key);
INSERT INTO `schema_migrations` (version) VALUES
('1');

"
      end

      def expected_schema_sql_on_production
        "CREATE SEQUENCE test_sequence OPTIONS (
  sequence_kind = 'bit_reversed_positive'
);
CREATE TABLE accounts (
  id INT64 NOT NULL,
  customer_id INT64,
  firm_id INT64,
  name STRING(MAX),
  credit_limit INT64,
  transactions_count INT64,
) PRIMARY KEY(id);
CREATE TABLE addresses (
  id INT64 NOT NULL,
  line1 STRING(MAX),
  postal_code STRING(MAX),
  city STRING(MAX),
  author_id INT64,
) PRIMARY KEY(id);
CREATE TABLE all_types (
  id INT64 NOT NULL,
  col_string STRING(MAX),
  col_int64 INT64,
  col_float64 FLOAT64,
  col_numeric NUMERIC,
  col_bool BOOL,
  col_bytes BYTES(MAX),
  col_date DATE,
  col_timestamp TIMESTAMP,
  col_json JSON,
  col_array_string ARRAY<STRING(MAX)>,
  col_array_int64 ARRAY<INT64>,
  col_array_float64 ARRAY<FLOAT64>,
  col_array_numeric ARRAY<NUMERIC>,
  col_array_bool ARRAY<BOOL>,
  col_array_bytes ARRAY<BYTES(MAX)>,
  col_array_date ARRAY<DATE>,
  col_array_timestamp ARRAY<TIMESTAMP>,
  col_array_json ARRAY<JSON>,
) PRIMARY KEY(id);
CREATE TABLE ar_internal_metadata (
  key STRING(MAX) NOT NULL,
  value STRING(MAX),
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
) PRIMARY KEY(key);
CREATE TABLE authors (
  id INT64 NOT NULL,
  name STRING(MAX) NOT NULL,
  registered_date DATE,
  organization_id INT64,
) PRIMARY KEY(id);
CREATE TABLE clubs (
  id INT64 NOT NULL,
  name STRING(MAX),
) PRIMARY KEY(id);
CREATE TABLE comments (
  id INT64 NOT NULL,
  comment STRING(MAX),
  post_id INT64,
) PRIMARY KEY(id);
CREATE TABLE customers (
  id INT64 NOT NULL,
  name STRING(MAX),
) PRIMARY KEY(id);
CREATE TABLE departments (
  id INT64 NOT NULL,
  name STRING(MAX),
  resource_type STRING(255),
  resource_id INT64,
) PRIMARY KEY(id);
CREATE INDEX index_departments_on_resource ON departments(resource_type, resource_id);
CREATE TABLE firms (
  id INT64 NOT NULL,
  name STRING(MAX),
  rating INT64,
  description STRING(MAX),
  account_id INT64,
) PRIMARY KEY(id);
CREATE INDEX index_firms_on_account_id ON firms(account_id);
CREATE TABLE member_types (
  id INT64 NOT NULL,
  name STRING(MAX),
) PRIMARY KEY(id);
CREATE TABLE members (
  id INT64 NOT NULL,
  name STRING(MAX),
  member_type_id INT64,
  admittable_type STRING(255),
  admittable_id INT64,
) PRIMARY KEY(id);
CREATE TABLE memberships (
  id INT64 NOT NULL,
  joined_on TIMESTAMP,
  club_id INT64,
  member_id INT64,
  favourite BOOL,
) PRIMARY KEY(id);
CREATE TABLE organizations (
  id INT64 NOT NULL,
  name STRING(MAX),
  last_updated TIMESTAMP OPTIONS (
    allow_commit_timestamp = true
  ),
) PRIMARY KEY(id);
CREATE TABLE posts (
  id INT64 NOT NULL,
  title STRING(MAX),
  content STRING(MAX),
  author_id INT64,
  comments_count INT64,
  post_date DATE,
  published_time TIMESTAMP,
) PRIMARY KEY(id);
ALTER TABLE comments ADD CONSTRAINT fk_rails_2fd19c0db7 FOREIGN KEY(post_id) REFERENCES posts(id);
CREATE INDEX index_posts_on_author_id ON posts(author_id);
CREATE TABLE schema_migrations (
  version STRING(MAX) NOT NULL,
) PRIMARY KEY(version);
CREATE TABLE singers (
  singerid INT64 NOT NULL,
  first_name STRING(200),
  last_name STRING(MAX),
  tracks_count INT64,
  lock_version INT64,
  full_name STRING(MAX) AS (COALESCE(first_name || ' ', '') || last_name) STORED,
) PRIMARY KEY(singerid);
CREATE TABLE albums (
  albumid INT64 NOT NULL,
  singerid INT64 NOT NULL,
  title STRING(MAX),
  lock_version INT64,
) PRIMARY KEY(singerid, albumid),
  INTERLEAVE IN PARENT singers ON DELETE NO ACTION;
CREATE TABLE tracks (
  trackid INT64 NOT NULL,
  singerid INT64 NOT NULL,
  albumid INT64 NOT NULL,
  title STRING(MAX),
  duration NUMERIC,
  lock_version INT64,
) PRIMARY KEY(singerid, albumid, trackid),
  INTERLEAVE IN PARENT albums ON DELETE CASCADE;
CREATE NULL_FILTERED INDEX index_tracks_on_singerid_and_albumid_and_title ON tracks(singerid, albumid, title), INTERLEAVE IN albums;
CREATE TABLE table_with_sequence (
  id INT64 NOT NULL DEFAULT (GET_NEXT_SEQUENCE_VALUE(SEQUENCE test_sequence)),
  name STRING(MAX) NOT NULL,
  age INT64 NOT NULL,
) PRIMARY KEY(id);
CREATE TABLE transactions (
  id INT64 NOT NULL,
  amount FLOAT64,
  account_id INT64,
) PRIMARY KEY(id);
INSERT INTO `schema_migrations` (version) VALUES
('1');

"
      end

      def expected_schema_sql_on_production_7_1
        "CREATE SEQUENCE test_sequence OPTIONS (
  sequence_kind = 'bit_reversed_positive'
);
CREATE TABLE accounts (
  id INT64 NOT NULL,
  customer_id INT64,
  firm_id INT64,
  name STRING(MAX),
  credit_limit INT64,
  transactions_count INT64,
) PRIMARY KEY(id);
CREATE TABLE addresses (
  id INT64 NOT NULL,
  line1 STRING(MAX),
  postal_code STRING(MAX),
  city STRING(MAX),
  author_id INT64,
) PRIMARY KEY(id);
CREATE TABLE all_types (
  id INT64 NOT NULL,
  col_string STRING(MAX),
  col_int64 INT64,
  col_float64 FLOAT64,
  col_numeric NUMERIC,
  col_bool BOOL,
  col_bytes BYTES(MAX),
  col_date DATE,
  col_timestamp TIMESTAMP,
  col_json JSON,
  col_array_string ARRAY<STRING(MAX)>,
  col_array_int64 ARRAY<INT64>,
  col_array_float64 ARRAY<FLOAT64>,
  col_array_numeric ARRAY<NUMERIC>,
  col_array_bool ARRAY<BOOL>,
  col_array_bytes ARRAY<BYTES(MAX)>,
  col_array_date ARRAY<DATE>,
  col_array_timestamp ARRAY<TIMESTAMP>,
  col_array_json ARRAY<JSON>,
) PRIMARY KEY(id);
CREATE TABLE ar_internal_metadata (
  key STRING(MAX) NOT NULL,
  value STRING(MAX),
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
) PRIMARY KEY(key);
CREATE TABLE authors (
  id INT64 NOT NULL,
  name STRING(MAX) NOT NULL,
  registered_date DATE,
  organization_id INT64,
) PRIMARY KEY(id);
CREATE TABLE clubs (
  id INT64 NOT NULL,
  name STRING(MAX),
) PRIMARY KEY(id);
CREATE TABLE comments (
  id INT64 NOT NULL,
  comment STRING(MAX),
  post_id INT64,
) PRIMARY KEY(id);
CREATE TABLE customers (
  id INT64 NOT NULL,
  name STRING(MAX),
) PRIMARY KEY(id);
CREATE TABLE departments (
  id INT64 NOT NULL,
  name STRING(MAX),
  resource_type STRING(255),
  resource_id INT64,
) PRIMARY KEY(id);
CREATE INDEX index_departments_on_resource ON departments(resource_type, resource_id);
CREATE TABLE firms (
  id INT64 NOT NULL,
  name STRING(MAX),
  rating INT64,
  description STRING(MAX),
  account_id INT64,
) PRIMARY KEY(id);
CREATE INDEX index_firms_on_account_id ON firms(account_id);
CREATE TABLE member_types (
  id INT64 NOT NULL,
  name STRING(MAX),
) PRIMARY KEY(id);
CREATE TABLE members (
  id INT64 NOT NULL,
  name STRING(MAX),
  member_type_id INT64,
  admittable_type STRING(255),
  admittable_id INT64,
) PRIMARY KEY(id);
CREATE TABLE memberships (
  id INT64 NOT NULL,
  joined_on TIMESTAMP,
  club_id INT64,
  member_id INT64,
  favourite BOOL,
) PRIMARY KEY(id);
CREATE TABLE organizations (
  id INT64 NOT NULL,
  name STRING(MAX),
  last_updated TIMESTAMP OPTIONS (
    allow_commit_timestamp = true
  ),
) PRIMARY KEY(id);
CREATE TABLE posts (
  id INT64 NOT NULL,
  title STRING(MAX),
  content STRING(MAX),
  author_id INT64,
  comments_count INT64,
  post_date DATE,
  published_time TIMESTAMP,
) PRIMARY KEY(id);
ALTER TABLE comments ADD CONSTRAINT fk_rails_2fd19c0db7 FOREIGN KEY(post_id) REFERENCES posts(id);
CREATE INDEX index_posts_on_author_id ON posts(author_id);
CREATE TABLE schema_migrations (
  version STRING(MAX) NOT NULL,
) PRIMARY KEY(version);
CREATE TABLE singers (
  singerid INT64 NOT NULL,
  first_name STRING(200),
  last_name STRING(MAX),
  tracks_count INT64,
  lock_version INT64,
  full_name STRING(MAX) AS (COALESCE(first_name || ' ', '') || last_name) STORED,
) PRIMARY KEY(singerid);
CREATE TABLE albums (
  singerid INT64 NOT NULL,
  albumid INT64 NOT NULL,
  title STRING(MAX),
  lock_version INT64,
) PRIMARY KEY(singerid, albumid),
  INTERLEAVE IN PARENT singers ON DELETE NO ACTION;
CREATE TABLE tracks (
  singerid INT64 NOT NULL,
  albumid INT64 NOT NULL,
  trackid INT64 NOT NULL,
  title STRING(MAX),
  duration NUMERIC,
  lock_version INT64,
) PRIMARY KEY(singerid, albumid, trackid),
  INTERLEAVE IN PARENT albums ON DELETE CASCADE;
CREATE NULL_FILTERED INDEX index_tracks_on_singerid_and_albumid_and_title ON tracks(singerid, albumid, title), INTERLEAVE IN albums;
CREATE TABLE table_with_sequence (
  id INT64 NOT NULL DEFAULT (GET_NEXT_SEQUENCE_VALUE(SEQUENCE test_sequence)),
  name STRING(MAX) NOT NULL,
  age INT64 NOT NULL,
) PRIMARY KEY(id);
CREATE TABLE transactions (
  id INT64 NOT NULL,
  amount FLOAT64,
  account_id INT64,
) PRIMARY KEY(id);
INSERT INTO `schema_migrations` (version) VALUES
('1');

"
      end
    end
  end
end

