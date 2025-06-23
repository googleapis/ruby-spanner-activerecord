# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "io/console"
require_relative "../config/environment"
require_relative "models/singer"
require_relative "models/album"

class Application
  def self.run
    singer_count = Singer.all.count
    album_count = Album.all.count
    puts ""
    puts "Singers in the database: #{singer_count}"
    puts "Albums in the database: #{album_count}"

    puts ""
    puts "Deleting all albums in the database using Partitioned DML"
    Album.transaction isolation: :pdml do
      count = Album.delete_all
      puts "Deleted #{count} albums"
    end

    puts ""
    puts "Deleting all singers in the database using Partitioned DML"
    Singer.transaction isolation: :pdml do
      count = Singer.delete_all
      puts "Deleted #{count} singers"
    end

    singer_count = Singer.all.count
    album_count = Album.all.count
    puts ""
    puts "Singers in the database: #{singer_count}"
    puts "Albums in the database: #{album_count}"
  end

  def self.run_two_dmls_in_pdml_transaction_test
    begin
      Singer.transaction isolation: :pdml do
        Album.delete_all
        Singer.delete_all
      end
    rescue ActiveRecord::StatementInvalid
      puts "  SUCCESS: As expected, the transaction failed because PDML only supports one DML statement."
    ensure
      Album.delete_all
      Singer.delete_all
    end
  end

  def self.demonstrate_successful_fallback
    begin
      singers_to_create = (1..10).map { |i| { first_name: "Test", last_name: "Singer #{i}" } }
      Singer.create singers_to_create
      puts "  #{Singer.count} singers now in database."

      puts "\n  Running a large delete operation with 'isolation: :fallback_to_pdml'..."
      puts "  NOTE: A real operation of this type on millions of rows could fail with a mutation limit error."
      puts "  The adapter would catch this error and automatically retry with a PDML transaction."

      Singer.transaction isolation: :fallback_to_pdml do
        Singer.where("last_name LIKE 'Singer %'").delete_all
      end

      puts "\n  SUCCESS: The transaction completed successfully thanks to the PDML fallback."
      puts "  Remaining singers: #{Singer.count}"
    rescue StandardError => e
      puts "\n  FAILED: The transaction unexpectedly failed with error: #{e.message}"
    ensure
      Singer.delete_all
    end
  end

  def self.demonstrate_no_fallback_when_disabled
    begin
      puts "  Running a transaction that will fail, without enabling the fallback..."

      Singer.transaction do
        # To demonstrate this, we simulate what Active Record would do if Spanner
        # returned a mutation limit error. It would raise a generic StatementInvalid error.
        puts "  Simulating a DML operation that exceeds the mutation limit..."
        raise ActiveRecordSpannerAdapter::TransactionMutationLimitExceededError,
              "Simulated: The transaction contains too many mutations"
      end
    rescue ActiveRecord::StatementInvalid
      puts "  SUCCESS: As expected, the transaction failed with a generic ActiveRecord::StatementInvalid."
      puts "  No fallback was attempted."
    end
  end
end

Application.run
Application.run_two_dmls_in_pdml_transaction_test

Application.demonstrate_successful_fallback
Application.demonstrate_no_fallback_when_disabled
