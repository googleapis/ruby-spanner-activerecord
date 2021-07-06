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
  def self.run
    puts "Deleting all existing Albums and Singers"
    Album.delete_all
    Singer.delete_all

    # Seed the database with 100 random singers.
    singer = create_singers 100

    execute_individual_benchmarks singer

    Benchmark.bm 75 do |bm|
      [1, 5, 10, 25, 50, 100, 200, 400].each do |parallel_benchmarks|
        bm.report "Total execution time (#{parallel_benchmarks}):" do
          threads = []
          parallel_benchmarks.times do
            threads << Thread.new do
              benchmark_select_one_singer singer
              benchmark_create_and_reload
              benchmark_create_albums_using_mutations
              benchmark_create_album_using_dml
              benchmark_select_100_singers
              benchmark_select_100_singers_in_read_only_transaction
              benchmark_select_100_singers_in_read_write_transaction
            end
          end
          threads.each(&:join)
        end
      end
    end

    puts ""
    puts "Press any key to end the application"
    STDIN.getch
  end

  def self.execute_individual_benchmarks singer
    puts ""
    Benchmark.bm 75 do |bm|
      bm.report "Select one row:" do
        benchmark_select_one_singer singer
      end

      bm.report "Save one row with fetch after:" do
        benchmark_create_and_reload
      end

      bm.report "Create 100 albums using mutations:" do
        benchmark_create_albums_using_mutations
      end

      bm.report "Create album using DML:" do
        benchmark_create_album_using_dml
      end

      bm.report "Select and iterate over 100 singers:" do
        benchmark_select_100_singers
      end

      bm.report "Select and iterate over 100 singers in a read-only transaction:" do
        benchmark_select_100_singers_in_read_only_transaction
      end

      bm.report "Select and iterate over 100 singers in a read/write transaction:" do
        benchmark_select_100_singers_in_read_write_transaction
      end
    end
  end

  def self.benchmark_select_one_singer singer
    Singer.find singer.id
  end

  def self.benchmark_create_and_reload
    singer = create_singers 1
    singer.reload
  end

  def self.benchmark_create_albums_using_mutations
    create_albums 100, :buffered_mutations
  end

  def self.benchmark_create_album_using_dml
    create_albums 1, :serializable
  end

  def self.benchmark_select_100_singers
    count = 0
    Singer.all.limit(100).each do
      count += 1
    end
  end

  def self.benchmark_select_100_singers_in_read_only_transaction
    count = 0
    Singer.transaction isolation: :read_only do
      Singer.all.limit(100).each do
        count += 1
      end
    end
  end

  def self.benchmark_select_100_singers_in_read_write_transaction
    count = 0
    Singer.transaction do
      Singer.all.limit(100).each do
        count += 1
      end
    end
  end

  def self.create_singers count
    first_names = %w[Pete Alice John Ethel Trudy Naomi Wendy Ruben Thomas Elly Cora Elise April Libby Alexandra Shania]
    last_names = %w[Wendelson Allison Peterson Johnson Henderson Ericsson Aronson Tennet Courtou Mcdonald Berry Ramirez]

    last_singer = nil
    Singer.transaction isolation: :buffered_mutations do
      count.times do
        last_singer = Singer.create first_name: first_names.sample, last_name: last_names.sample,
                                    birth_date: Date.new(rand(1920..2005), rand(1..12), rand(1..28)),
                                    picture: StringIO.new("some-picture-#{SecureRandom.uuid}")
      end
    end
    last_singer
  end

  def self.create_albums count, isolation
    singer = Singer.all.sample
    Album.transaction isolation: isolation do
      count.times do
        Album.create singer: singer, title: "Some random title", release_date: Date.new(2021, 7, 1)
      end
    end
  end
end

Application.run
