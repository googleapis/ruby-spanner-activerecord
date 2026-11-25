# Copyright 2026 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# frozen_string_literal: true

require "test_helper"

class SpannerConnectionCacheTest < Minitest::Test
  def setup
    super
    ActiveRecordSpannerAdapter::Connection.reset_information_schemas!
    ActiveRecordSpannerAdapter::Connection.reset_spanners!
  end

  def teardown
    ActiveRecordSpannerAdapter::Connection.reset_information_schemas!
    ActiveRecordSpannerAdapter::Connection.reset_spanners!
    super
  end

  def base_config overrides = {}
    {
      project: "test-project",
      instance: "test-instance",
      database: "test-database",
      credentials: "writer-credentials.json"
    }.merge overrides
  end

  def stub_spanner_new
    created_arguments = []
    factory = lambda do |**kwargs|
      client = Object.new
      created_arguments << [client, kwargs]
      client
    end

    Google::Cloud::Spanner.stub :new, factory do
      yield created_arguments
    end
  end

  def test_spanners_reuses_client_for_equivalent_configs
    stub_spanner_new do |created|
      first_client = ActiveRecordSpannerAdapter::Connection.spanners base_config
      string_key_config = {
        "project" => "test-project",
        "instance" => "test-instance",
        "database" => "test-database",
        "credentials" => "writer-credentials.json"
      }
      second_client = ActiveRecordSpannerAdapter::Connection.spanners string_key_config

      assert_same first_client, second_client
      assert_equal 1, created.length
    end
  end

  def test_spanners_isolates_different_credential_paths_for_same_database
    stub_spanner_new do |created|
      writer_client = ActiveRecordSpannerAdapter::Connection.spanners base_config(credentials: "writer.json")
      reader_client = ActiveRecordSpannerAdapter::Connection.spanners base_config(credentials: "reader.json")

      refute_same writer_client, reader_client
      assert_equal 2, created.length
      assert_equal "writer.json", created[0][1][:credentials]
      assert_equal "reader.json", created[1][1][:credentials]
    end
  end

  def test_spanners_isolates_nil_vs_explicit_credentials
    stub_spanner_new do |created|
      default_client = ActiveRecordSpannerAdapter::Connection.spanners base_config(credentials: nil)
      explicit_client = ActiveRecordSpannerAdapter::Connection.spanners base_config(credentials: "writer.json")

      refute_same default_client, explicit_client
      assert_equal 2, created.length
    end
  end

  def test_spanners_isolates_hash_credentials_and_does_not_leak_private_key_in_cache_keys
    writer_hash = {
      "type" => "service_account",
      "client_email" => "writer@example.iam.gserviceaccount.com",
      "private_key" => "SUPER_SECRET_WRITER_KEY"
    }
    reader_hash = {
      "type" => "service_account",
      "client_email" => "reader@example.iam.gserviceaccount.com",
      "private_key" => "SUPER_SECRET_READER_KEY"
    }

    stub_spanner_new do |created|
      writer_client = ActiveRecordSpannerAdapter::Connection.spanners base_config(credentials: writer_hash)
      reader_client = ActiveRecordSpannerAdapter::Connection.spanners base_config(credentials: reader_hash)

      refute_same writer_client, reader_client
      assert_equal 2, created.length

      equivalent_writer_hash = {
        private_key: "SUPER_SECRET_WRITER_KEY",
        client_email: "writer@example.iam.gserviceaccount.com",
        type: "service_account"
      }
      reused_writer_client = ActiveRecordSpannerAdapter::Connection.spanners(
        base_config(credentials: equivalent_writer_hash)
      )
      assert_same writer_client, reused_writer_client

      cache_keys = ActiveRecordSpannerAdapter::Connection.instance_variable_get(:@spanners).keys
      refute_includes cache_keys.inspect, "SUPER_SECRET_WRITER_KEY"
      refute_includes cache_keys.inspect, "SUPER_SECRET_READER_KEY"
    end
  end

  def test_spanners_immune_to_caller_mutation_of_config_strings_and_structures
    mutable_instance = +"instance-one"
    mutable_database = +"database-one"
    mutable_path = +"writer.json"
    mutable_hash = { "client_email" => +"writer@example.iam.gserviceaccount.com" }
    mutable_scope = [+"https://www.googleapis.com/auth/spanner.data"]

    stub_spanner_new do
      path_client = ActiveRecordSpannerAdapter::Connection.spanners(
        base_config(
          instance: mutable_instance,
          database: mutable_database,
          credentials: mutable_path,
          scope: mutable_scope
        )
      )
      mutable_instance.replace "instance-two"
      mutable_database.replace "database-two"
      mutable_path.replace "reader.json"
      mutable_scope[0].replace "https://www.googleapis.com/auth/spanner"

      new_path_client = ActiveRecordSpannerAdapter::Connection.spanners(
        base_config(
          instance: "instance-two",
          database: "database-two",
          credentials: "reader.json",
          scope: ["https://www.googleapis.com/auth/spanner"]
        )
      )
      original_path_client = ActiveRecordSpannerAdapter::Connection.spanners(
        base_config(
          instance: "instance-one",
          database: "database-one",
          credentials: "writer.json",
          scope: ["https://www.googleapis.com/auth/spanner.data"]
        )
      )
      assert_same path_client, original_path_client
      refute_same path_client, new_path_client

      hash_client = ActiveRecordSpannerAdapter::Connection.spanners base_config(credentials: mutable_hash)
      mutable_hash["client_email"] = "reader@example.iam.gserviceaccount.com"

      new_hash_client = ActiveRecordSpannerAdapter::Connection.spanners(
        base_config(credentials: { "client_email" => "reader@example.iam.gserviceaccount.com" })
      )
      original_hash_client = ActiveRecordSpannerAdapter::Connection.spanners(
        base_config(credentials: { "client_email" => "writer@example.iam.gserviceaccount.com" })
      )
      assert_same hash_client, original_hash_client
      refute_same hash_client, new_hash_client
    end
  end

  def test_spanners_isolates_distinct_credential_objects
    first_credentials = Object.new
    second_credentials = Object.new

    stub_spanner_new do |created|
      first_client = ActiveRecordSpannerAdapter::Connection.spanners base_config(credentials: first_credentials)
      second_client = ActiveRecordSpannerAdapter::Connection.spanners base_config(credentials: second_credentials)
      reused_first_client = ActiveRecordSpannerAdapter::Connection.spanners base_config(credentials: first_credentials)

      assert_same first_client, reused_first_client
      refute_same first_client, second_client
      assert_equal 2, created.length
    end
  end

  def test_spanners_isolates_scope_and_timeout
    stub_spanner_new do |created|
      read_only_scope_client = ActiveRecordSpannerAdapter::Connection.spanners(
        base_config(scope: "https://www.googleapis.com/auth/spanner.data")
      )
      same_scope_array_client = ActiveRecordSpannerAdapter::Connection.spanners(
        base_config(scope: ["https://www.googleapis.com/auth/spanner.data"])
      )
      admin_scope_client = ActiveRecordSpannerAdapter::Connection.spanners(
        base_config(scope: ["https://www.googleapis.com/auth/spanner.admin"])
      )
      short_timeout_client = ActiveRecordSpannerAdapter::Connection.spanners(
        base_config(scope: "https://www.googleapis.com/auth/spanner.data", timeout: 5)
      )

      assert_same read_only_scope_client, same_scope_array_client
      refute_same read_only_scope_client, admin_scope_client
      refute_same read_only_scope_client, short_timeout_client
      assert_equal 3, created.length
    end
  end

  def test_spanners_respects_dynamic_emulator_host_env
    original_env = ENV["SPANNER_EMULATOR_HOST"]
    stub_spanner_new do |created|
      ENV["SPANNER_EMULATOR_HOST"] = "localhost:9010"
      first_client = ActiveRecordSpannerAdapter::Connection.spanners(
        base_config(credentials: nil, emulator_host: nil)
      )

      ENV["SPANNER_EMULATOR_HOST"] = "localhost:9020"
      second_client = ActiveRecordSpannerAdapter::Connection.spanners(
        base_config(credentials: nil, emulator_host: nil)
      )

      refute_same first_client, second_client
      assert_equal 2, created.length
    end
  ensure
    ENV["SPANNER_EMULATOR_HOST"] = original_env
  end

  def test_information_schema_isolates_different_credentials_scope_and_timeout
    stub_spanner_new do
      writer_schema = ActiveRecordSpannerAdapter::Connection.information_schema(
        base_config(credentials: "writer.json")
      )
      reader_schema = ActiveRecordSpannerAdapter::Connection.information_schema(
        base_config(credentials: "reader.json")
      )
      scoped_schema = ActiveRecordSpannerAdapter::Connection.information_schema(
        base_config(credentials: "writer.json", scope: ["https://www.googleapis.com/auth/spanner.data"])
      )
      timeout_schema = ActiveRecordSpannerAdapter::Connection.information_schema(
        base_config(credentials: "writer.json", timeout: 10)
      )
      reused_writer_schema = ActiveRecordSpannerAdapter::Connection.information_schema(
        {
          "project" => "test-project",
          "instance" => "test-instance",
          "database" => "test-database",
          "credentials" => "writer.json"
        }
      )

      assert_same writer_schema, reused_writer_schema
      refute_same writer_schema, reader_schema
      refute_same writer_schema, scoped_schema
      refute_same writer_schema, timeout_schema
      refute_same writer_schema.connection.spanner, reader_schema.connection.spanner
    end
  end

  def test_reset_information_schemas_clears_cache_and_disconnects_sessions
    released_sessions = 0
    mock_session = Object.new
    mock_session.define_singleton_method(:release!) { released_sessions += 1 }
    mock_project = Object.new
    mock_project.define_singleton_method(:create_session) { |_instance, _database| mock_session }

    Google::Cloud::Spanner.stub :new, mock_project do
      active_schema = ActiveRecordSpannerAdapter::Connection.information_schema(
        base_config(credentials: "active.json")
      )
      # Initialize a session on active_schema only.
      active_schema.connection.session

      lazy_schema = ActiveRecordSpannerAdapter::Connection.information_schema(
        base_config(credentials: "lazy.json")
      )

      ActiveRecordSpannerAdapter::Connection.reset_information_schemas!

      # Only the initialized session should be released; lazy_schema should not create one just to disconnect.
      assert_equal 1, released_sessions
      assert_nil active_schema.connection.instance_variable_get(:@session)
      assert_nil lazy_schema.connection.instance_variable_get(:@session)

      recreated_schema = ActiveRecordSpannerAdapter::Connection.information_schema(
        base_config(credentials: "active.json")
      )
      refute_same active_schema, recreated_schema
    end
  end

  def test_concurrent_information_schema_lookup_is_thread_safe
    thread_count = 6
    ready_queue = Queue.new
    start_queue = Queue.new

    stub_spanner_new do
      threads = Array.new(thread_count) do
        Thread.new do
          ready_queue << true
          start_queue.pop
          ActiveRecordSpannerAdapter::Connection.information_schema(base_config(credentials: "shared.json"))
        end
      end

      thread_count.times { ready_queue.pop }
      thread_count.times { start_queue << true }
      schemas = threads.map(&:value)

      assert_equal 1, schemas.uniq(&:object_id).length
    end
  end

  def test_concurrent_spanners_lookup_is_thread_safe
    thread_count = 6
    ready_queue = Queue.new
    start_queue = Queue.new

    stub_spanner_new do |created|
      threads = Array.new(thread_count) do |index|
        credentials = index.even? ? "writer.json" : "reader.json"
        Thread.new do
          ready_queue << true
          start_queue.pop
          ActiveRecordSpannerAdapter::Connection.spanners(base_config(credentials: credentials))
        end
      end

      thread_count.times { ready_queue.pop }
      thread_count.times { start_queue << true }
      clients = threads.map(&:value)

      assert_equal 2, created.length
      assert_equal 2, clients.uniq(&:object_id).length
    end
  end

  def test_connection_initialize_and_database_path_accept_string_keys
    stub_spanner_new do
      string_config = {
        "project" => "test-project",
        "instance" => "test-instance",
        "database" => "test-database",
        "credentials" => "writer.json",
        "isolation_level" => :repeatable_read
      }
      connection = ActiveRecordSpannerAdapter::Connection.new string_config

      assert_equal "test-instance", connection.instance_id
      assert_equal "test-database", connection.database_id
      assert_equal :repeatable_read, connection.isolation_level
      assert_equal(
        "/test-project/test-instance/test-database",
        ActiveRecordSpannerAdapter::Connection.database_path(string_config)
      )
    end
  end

  def test_reset_spanners_clears_cached_clients
    stub_spanner_new do |created|
      first_client = ActiveRecordSpannerAdapter::Connection.spanners base_config
      ActiveRecordSpannerAdapter::Connection.reset_spanners!
      second_client = ActiveRecordSpannerAdapter::Connection.spanners base_config

      refute_same first_client, second_client
      assert_equal 2, created.length
    end
  end

  def test_reset_information_schemas_continues_and_clears_cache_when_disconnect_raises
    released_sessions = 0
    failing_session = Object.new
    failing_session.define_singleton_method(:release!) { raise Google::Cloud::NotFoundError, "Database not found" }

    healthy_session = Object.new
    healthy_session.define_singleton_method(:release!) { released_sessions += 1 }

    failing_project = Object.new
    failing_project.define_singleton_method(:create_session) { |_instance, _database| failing_session }

    healthy_project = Object.new
    healthy_project.define_singleton_method(:create_session) { |_instance, _database| healthy_session }

    projects = [failing_project, healthy_project]
    Google::Cloud::Spanner.stub :new, ->(**) { projects.shift } do
      # Resetting before any information schema is cached is a safe no-op.
      ActiveRecordSpannerAdapter::Connection.instance_variable_set :@information_schemas, nil
      assert_nil ActiveRecordSpannerAdapter::Connection.reset_information_schemas!

      failing_schema = ActiveRecordSpannerAdapter::Connection.information_schema(
        base_config(credentials: "failing.json")
      )
      failing_schema.connection.session

      healthy_schema = ActiveRecordSpannerAdapter::Connection.information_schema(
        base_config(credentials: "healthy.json")
      )
      healthy_schema.connection.session

      mutex_locked_during_disconnect = nil
      info_mutex = ActiveRecordSpannerAdapter::Connection.instance_variable_get :@information_schemas_mutex
      healthy_session.define_singleton_method(:release!) do
        mutex_locked_during_disconnect = info_mutex.locked?
        released_sessions += 1
      end

      ActiveRecordSpannerAdapter::Connection.reset_information_schemas!

      assert_equal 1, released_sessions
      assert_equal false, mutex_locked_during_disconnect
      assert_nil failing_schema.connection.instance_variable_get(:@session)
      assert_nil healthy_schema.connection.instance_variable_get(:@session)
      assert_equal({}, ActiveRecordSpannerAdapter::Connection.instance_variable_get(:@information_schemas))
    end
  end

  def test_concurrent_shared_connection_session_creation_is_thread_safe
    thread_count = 6
    ready_queue = Queue.new
    start_queue = Queue.new
    created_sessions = 0
    counter_mutex = Mutex.new
    mock_project = Object.new
    mock_project.define_singleton_method(:create_session) do |_instance, _database|
      counter_mutex.synchronize { created_sessions += 1 }
      Object.new
    end

    Google::Cloud::Spanner.stub :new, mock_project do
      info_schema = ActiveRecordSpannerAdapter::Connection.information_schema(
        base_config(credentials: "shared-session.json")
      )
      threads = Array.new(thread_count) do
        Thread.new do
          ready_queue << true
          start_queue.pop
          info_schema.connection.session
        end
      end

      thread_count.times { ready_queue.pop }
      thread_count.times { start_queue << true }
      sessions = threads.map(&:value)

      assert_equal 1, created_sessions
      assert_equal 1, sessions.uniq(&:object_id).length
    end
  end

  def test_disconnect_clears_session_even_when_release_raises
    mutex_locked_during_release = nil
    failing_session = Object.new
    mock_project = Object.new
    mock_project.define_singleton_method(:create_session) { |_instance, _database| failing_session }

    Google::Cloud::Spanner.stub :new, mock_project do
      connection = ActiveRecordSpannerAdapter::Connection.new base_config
      session_mutex = connection.instance_variable_get :@session_mutex
      failing_session.define_singleton_method(:release!) do
        mutex_locked_during_release = session_mutex.locked?
        raise StandardError, "network error"
      end

      connection.session
      refute_nil connection.instance_variable_get(:@session)

      error = assert_raises(StandardError) { connection.disconnect! }
      assert_equal "network error", error.message
      assert_equal false, mutex_locked_during_release
      assert_nil connection.instance_variable_get(:@session)
    end
  end

  def test_spanners_credential_permutations_symbol_pathname_empty_string_and_unmarshalable_hash
    stub_spanner_new do
      symbol_client = ActiveRecordSpannerAdapter::Connection.spanners(
        base_config(credentials: :this_channel_is_insecure)
      )
      symbol_string_client = ActiveRecordSpannerAdapter::Connection.spanners(
        base_config(credentials: "this_channel_is_insecure")
      )
      refute_same symbol_client, symbol_string_client

      pathname_client = ActiveRecordSpannerAdapter::Connection.spanners(
        base_config(credentials: Pathname.new("writer.json"))
      )
      string_path_client = ActiveRecordSpannerAdapter::Connection.spanners(
        base_config(credentials: "writer.json")
      )
      other_pathname_client = ActiveRecordSpannerAdapter::Connection.spanners(
        base_config(credentials: Pathname.new("reader.json"))
      )
      assert_same pathname_client, string_path_client
      refute_same pathname_client, other_pathname_client

      empty_string_client = ActiveRecordSpannerAdapter::Connection.spanners(base_config(credentials: ""))
      nil_client = ActiveRecordSpannerAdapter::Connection.spanners(base_config(credentials: nil))
      refute_same empty_string_client, nil_client

      # Hashes containing non-serializable Ruby objects like `proc {}` (anonymous functions) cannot
      # be serialized with `Marshal.dump`, so `normalize_credentials_key` falls back to caching
      # a deep-frozen copy of the canonicalized Hash (`[:hash_object, canonical]`).
      # Note: `+"writer"` creates a mutable copy of a string literal (since this file uses
      # `frozen_string_literal: true`), allowing us to mutate the caller's nested Hash in-place
      # and verify that the cached entry remains intact and separate from the mutated config.
      updater = proc {}
      unmarshalable_first = { "updater" => updater, "nested" => { "role" => +"writer" } }
      unmarshalable_second = { "updater" => proc {} }
      unmarshalable_client_one = ActiveRecordSpannerAdapter::Connection.spanners(
        base_config(credentials: unmarshalable_first)
      )
      unmarshalable_client_two = ActiveRecordSpannerAdapter::Connection.spanners(
        base_config(credentials: unmarshalable_second)
      )

      # Mutate the caller's hash and nested string in-place after caching.
      unmarshalable_first["nested"]["role"].replace "reader"
      unmarshalable_first["extra"] = "mutated"

      # A fresh equivalent hash matching the original values still hits the cached client,
      # while the mutated hash is treated as a distinct configuration.
      reused_unmarshalable_client = ActiveRecordSpannerAdapter::Connection.spanners(
        base_config(credentials: { updater: updater, nested: { role: "writer" } })
      )
      mutated_unmarshalable_client = ActiveRecordSpannerAdapter::Connection.spanners(
        base_config(credentials: unmarshalable_first)
      )
      refute_same unmarshalable_client_one, unmarshalable_client_two
      assert_same unmarshalable_client_one, reused_unmarshalable_client
      refute_same unmarshalable_client_one, mutated_unmarshalable_client
    end
  end

  def test_spanners_nested_hash_type_distinction_and_binary_strings
    stub_spanner_new do
      nested_string_keys = {
        "auth" => [{ "key" => "value", "count" => 1, "flag" => true, "extra" => nil }]
      }
      nested_symbol_keys = {
        auth: [{ flag: true, extra: nil, count: 1, key: "value" }]
      }
      different_types = {
        "auth" => [{ "key" => "value", "count" => "1", "flag" => "true", "extra" => "" }]
      }
      hash_shape = { "x" => { "a" => 1 } }
      array_shape = { "x" => [["a", 1]] }
      ascii_8bit_hash_one = { "bytes" => "\xFF\xFE".b, "\xFE".b => 1, "utf8" => "ok" }
      ascii_8bit_hash_two = { "bytes" => "\xFF\xFD".b, "\xFE".b => 1, "utf8" => "ok" }
      invalid_utf8_hash_one = { "bytes" => (+"\xFF\xFE").force_encoding(Encoding::UTF_8) }
      invalid_utf8_hash_two = { "bytes" => (+"\xFF\xFD").force_encoding(Encoding::UTF_8) }

      client_one = ActiveRecordSpannerAdapter::Connection.spanners(base_config(credentials: nested_string_keys))
      client_two = ActiveRecordSpannerAdapter::Connection.spanners(base_config(credentials: nested_symbol_keys))
      client_diff_types = ActiveRecordSpannerAdapter::Connection.spanners(base_config(credentials: different_types))
      client_hash_shape = ActiveRecordSpannerAdapter::Connection.spanners(base_config(credentials: hash_shape))
      client_array_shape = ActiveRecordSpannerAdapter::Connection.spanners(base_config(credentials: array_shape))
      client_ascii_8bit_one = ActiveRecordSpannerAdapter::Connection.spanners(
        base_config(credentials: ascii_8bit_hash_one)
      )
      client_ascii_8bit_two = ActiveRecordSpannerAdapter::Connection.spanners(
        base_config(credentials: ascii_8bit_hash_two)
      )
      client_binary_one = ActiveRecordSpannerAdapter::Connection.spanners(base_config(credentials: invalid_utf8_hash_one))
      client_binary_two = ActiveRecordSpannerAdapter::Connection.spanners(base_config(credentials: invalid_utf8_hash_two))

      assert_same client_one, client_two
      refute_same client_one, client_diff_types
      refute_same client_hash_shape, client_array_shape
      refute_same client_ascii_8bit_one, client_ascii_8bit_two
      refute_same client_binary_one, client_binary_two
    end
  end

  def test_spanners_tracks_default_credentials_and_json_env_vars
    original_gac = ENV["GOOGLE_APPLICATION_CREDENTIALS"]
    original_spanner_json = ENV["SPANNER_CREDENTIALS_JSON"]
    original_emulator = ENV["SPANNER_EMULATOR_HOST"]

    stub_spanner_new do
      ENV.delete "SPANNER_EMULATOR_HOST"
      ENV["GOOGLE_APPLICATION_CREDENTIALS"] = "adc-writer.json"
      adc_writer = ActiveRecordSpannerAdapter::Connection.spanners(base_config(credentials: nil))

      ENV["GOOGLE_APPLICATION_CREDENTIALS"] = "adc-reader.json"
      adc_reader = ActiveRecordSpannerAdapter::Connection.spanners(base_config(credentials: nil))
      refute_same adc_writer, adc_reader

      ENV["SPANNER_CREDENTIALS_JSON"] = '{"private_key":"SECRET_ENV_KEY_1"}'
      json_env_one = ActiveRecordSpannerAdapter::Connection.spanners(base_config(credentials: nil))
      ENV["SPANNER_CREDENTIALS_JSON"] = '{"private_key":"SECRET_ENV_KEY_2"}'
      json_env_two = ActiveRecordSpannerAdapter::Connection.spanners(base_config(credentials: nil))
      refute_same json_env_one, json_env_two

      cache_keys = ActiveRecordSpannerAdapter::Connection.instance_variable_get(:@spanners).keys
      refute_includes cache_keys.inspect, "SECRET_ENV_KEY_1"
      refute_includes cache_keys.inspect, "SECRET_ENV_KEY_2"
    end
  ensure
    ENV["GOOGLE_APPLICATION_CREDENTIALS"] = original_gac
    ENV["SPANNER_CREDENTIALS_JSON"] = original_spanner_json
    ENV["SPANNER_EMULATOR_HOST"] = original_emulator
  end

  def test_spanners_normalizes_emulator_host_and_handles_nil_fields
    original_gac = ENV["GOOGLE_APPLICATION_CREDENTIALS"]
    original_emulator = ENV["SPANNER_EMULATOR_HOST"]

    stub_spanner_new do
      ENV.delete "SPANNER_EMULATOR_HOST"
      emulator_first = ActiveRecordSpannerAdapter::Connection.spanners(
        base_config(credentials: nil, emulator_host: "localhost:9010")
      )
      ENV["GOOGLE_APPLICATION_CREDENTIALS"] = "adc-other.json"
      emulator_second = ActiveRecordSpannerAdapter::Connection.spanners(
        base_config(credentials: nil, emulator_host: "localhost:9010")
      )
      assert_same emulator_first, emulator_second

      nil_emulator = ActiveRecordSpannerAdapter::Connection.spanners(
        base_config(credentials: nil, emulator_host: nil)
      )
      blank_emulator = ActiveRecordSpannerAdapter::Connection.spanners(
        base_config(credentials: nil, emulator_host: "   ")
      )
      assert_same nil_emulator, blank_emulator

      nil_configure = OpenStruct.new(emulator_host: nil, project_id: nil, credentials: nil, scope: nil, timeout: nil)
      Google::Cloud::Spanner.stub :configure, nil_configure do
        nil_fields_client = ActiveRecordSpannerAdapter::Connection.spanners(
          project: nil, instance: nil, database: nil, credentials: "writer.json", scope: nil
        )
        refute_nil nil_fields_client
      end
    end
  ensure
    ENV["GOOGLE_APPLICATION_CREDENTIALS"] = original_gac
    ENV["SPANNER_EMULATOR_HOST"] = original_emulator
  end

  def test_spanners_tracks_global_configure_overrides
    original_emulator = ENV["SPANNER_EMULATOR_HOST"]
    configure = Google::Cloud::Spanner.configure
    cloud_configure = Google::Cloud.configure
    original_credentials = configure.credentials
    original_cloud_credentials = cloud_configure.credentials
    original_scope = configure.scope
    original_timeout = configure.timeout
    original_project = configure.project_id
    original_cloud_project = cloud_configure.project_id

    stub_spanner_new do
      ENV.delete "SPANNER_EMULATOR_HOST"

      configure.credentials = "configured-first.json"
      configured_creds_one = ActiveRecordSpannerAdapter::Connection.spanners(base_config(credentials: nil))
      configure.credentials = nil
      cloud_configure.credentials = "cloud-configured.json"
      configured_creds_two = ActiveRecordSpannerAdapter::Connection.spanners(base_config(credentials: nil))
      refute_same configured_creds_one, configured_creds_two
      cloud_configure.credentials = nil

      configure.scope = ["https://www.googleapis.com/auth/spanner.data"]
      configured_scope_one = ActiveRecordSpannerAdapter::Connection.spanners(base_config(scope: nil))
      empty_scope_client = ActiveRecordSpannerAdapter::Connection.spanners(base_config(scope: []))
      refute_same configured_scope_one, empty_scope_client

      configure.timeout = 10
      configured_timeout_one = ActiveRecordSpannerAdapter::Connection.spanners(base_config(timeout: nil))
      configure.timeout = 20
      configured_timeout_two = ActiveRecordSpannerAdapter::Connection.spanners(base_config(timeout: nil))
      refute_same configured_timeout_one, configured_timeout_two

      configure.project_id = "configured-proj-one"
      configured_proj_one = ActiveRecordSpannerAdapter::Connection.spanners(base_config(project: nil))
      configure.project_id = nil
      cloud_configure.project_id = "cloud-proj-two"
      configured_proj_two = ActiveRecordSpannerAdapter::Connection.spanners(base_config(project: nil))
      refute_same configured_proj_one, configured_proj_two
    end
  ensure
    ENV["SPANNER_EMULATOR_HOST"] = original_emulator
    configure.credentials = original_credentials
    cloud_configure.credentials = original_cloud_credentials
    configure.scope = original_scope
    configure.timeout = original_timeout
    configure.project_id = original_project
    cloud_configure.project_id = original_cloud_project
  end
end
