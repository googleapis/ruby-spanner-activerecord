# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "benchmark"
require "io/console"
require "securerandom"
require_relative "config/environment"
require_relative "models/singer"
require_relative "models/album"

class Application
  def self.run # rubocop:disable Metrics/AbcSize
    config = ActiveRecord::Base.connection_config
    spanner = Google::Cloud::Spanner.new project: config[:project], credentials: config[:credentials]
    spanner_client = spanner.client config[:instance], config[:database], pool: { max: config[:pool], fail: false }

    [nil, spanner_client].each do |client|
      puts ""
      puts ""
      puts "Benchmarks for #{client ? 'Spanner client' : 'ActiveRecord'}"
      Album.delete_all
      Singer.delete_all

      # Seed the database with 100 random singers.
      singer = create_singers 100, client

      execute_individual_benchmarks singer, client

      Benchmark.bm 75 do |bm|
        [1, 5, 10, 25, 50, 100, 200, 400].each do |parallel_benchmarks|
          bm.report "Total execution time (#{parallel_benchmarks}):" do
            threads = []
            parallel_benchmarks.times do
              threads << Thread.new do
                benchmark_select_one_singer singer, client
                benchmark_create_and_reload client
                benchmark_create_albums_using_mutations client
                benchmark_create_album_using_dml client
                benchmark_select_100_singers client
                benchmark_select_100_singers_in_read_only_transaction client
                benchmark_select_100_singers_in_read_write_transaction client
              end
            end
            threads.each(&:join)
          end
        end
      end
    end

    spanner_client.close
    ActiveRecord::Base.connection_pool.disconnect

    puts ""
    puts "Press any key to end the application"
    STDIN.getch
  end

  def self.execute_individual_benchmarks singer, client
    puts ""
    Benchmark.bm 75 do |bm|
      bm.report "Select one row:" do
        benchmark_select_one_singer singer, client
      end

      bm.report "Save one row with fetch after:" do
        benchmark_create_and_reload client
      end

      bm.report "Create 100 albums using mutations:" do
        benchmark_create_albums_using_mutations client
      end

      bm.report "Create album using DML:" do
        benchmark_create_album_using_dml client
      end

      bm.report "Select and iterate over 100 singers:" do
        benchmark_select_100_singers client
      end

      bm.report "Select and iterate over 100 singers in a read-only transaction:" do
        benchmark_select_100_singers_in_read_only_transaction client
      end

      bm.report "Select and iterate over 100 singers in a read/write transaction:" do
        benchmark_select_100_singers_in_read_write_transaction client
      end
    end
  end

  def self.benchmark_select_one_singer singer, client
    if client
      sql = "SELECT * FROM Singers WHERE id=@id"
      params = { id: singer[:id] }
      param_types = { id: :INT64 }
      client.execute(sql, params: params, types: param_types).rows.each do |row|
        return row
      end
    else
      Singer.find singer.id
    end
  end

  def self.benchmark_create_and_reload client
    singer = create_singers 1, client
    if client
      sql = "SELECT * FROM Singers WHERE id=@id"
      params = { id: singer[:id] }
      param_types = { id: :INT64 }
      client.execute(sql, params: params, types: param_types).rows.each do |row|
        return row
      end
    else
      singer.reload
    end
  end

  def self.benchmark_create_albums_using_mutations client
    create_albums 100, :buffered_mutations, client
  end

  def self.benchmark_create_album_using_dml client
    create_albums 1, :serializable, client
  end

  def self.benchmark_select_100_singers client
    count = 0
    if client
      client.execute("SELECT * FROM singers LIMIT 100").rows.each do |_row|
        count += 1
      end
    else
      Singer.all.limit(100).each do
        count += 1
      end
    end
  end

  def self.benchmark_select_100_singers_in_read_only_transaction client
    count = 0
    if client
      client.snapshot do |snapshot|
        snapshot.execute("SELECT * FROM singers LIMIT 100").rows.each do |_row|
          count += 1
        end
      end
    else
      Singer.transaction isolation: :read_only do
        Singer.all.limit(100).each do
          count += 1
        end
      end
    end
  end

  def self.benchmark_select_100_singers_in_read_write_transaction client
    count = 0
    if client
      client.transaction do |transaction|
        transaction.execute("SELECT * FROM singers LIMIT 100").rows.each do |_row|
          count += 1
        end
      end
    else
      Singer.transaction do
        Singer.all.limit(100).each do
          count += 1
        end
      end
    end
  end

  def self.create_singers count, client
    first_names = %w[Pete Alice John Ethel Trudy Naomi Wendy Ruben Thomas Elly Cora Elise April Libby Alexandra Shania]
    last_names = %w[Wendelson Allison Peterson Johnson Henderson Ericsson Aronson Tennet Courtou Mcdonald Berry Ramirez]

    last_singer = nil
    if client
      client.commit do |c|
        singers = []
        count.times do
          last_singer = { id: SecureRandom.uuid.gsub("-", "").hex & 0x7FFFFFFFFFFFFFFF,
                          first_name: first_names.sample, last_name: last_names.sample,
                          birth_date: Date.new(rand(1920..2005), rand(1..12), rand(1..28)),
                          picture: StringIO.new("some-picture-#{SecureRandom.uuid}") }
          singers << last_singer
        end
        c.insert "singers", singers
      end
    else
      Singer.transaction isolation: :buffered_mutations do
        count.times do
          last_singer = Singer.create first_name: first_names.sample, last_name: last_names.sample,
                                      birth_date: Date.new(rand(1920..2005), rand(1..12), rand(1..28)),
                                      picture: StringIO.new("some-picture-#{SecureRandom.uuid}")
        end
      end
    end
    last_singer
  end

  def self.create_albums count, isolation, client
    singer = Singer.all.sample
    if client
      if isolation == :buffered_mutations
        client.commit do |c|
          albums = []
          count.times do
            albums << { id: SecureRandom.uuid.gsub("-", "").hex & 0x7FFFFFFFFFFFFFFF,
                        singer_id: singer.id, title: "Some random title",
                        release_date: Date.new(2021, 7, 1) }
          end
          c.insert "albums", albums
        end
      else
        client.transaction do |transaction|
          sql = "INSERT INTO albums (id, singer_id, title, release_date) VALUES (@id, @singer, @title, @release_date)"
          transaction.batch_update do |b|
            count.times do
              params = { id: SecureRandom.uuid.gsub("-", "").hex & 0x7FFFFFFFFFFFFFFF, singer: singer.id,
                         title: "Some random title", release_date: Date.new(2021, 7, 1) }
              param_types = { id: :INT64, singer: :INT64, title: :STRING, release_date: :DATE }
              b.batch_update sql, params: params, types: param_types
            end
          end
        end
      end
    else
      Album.transaction isolation: isolation do
        count.times do
          Album.create singer: singer, title: "Some random title", release_date: Date.new(2021, 7, 1)
        end
      end
    end
  end
end

Application.run
