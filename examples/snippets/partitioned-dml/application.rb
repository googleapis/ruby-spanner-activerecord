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
  def self.run # rubocop:disable Metrics/AbcSize
    singer_count = Singer.all.count
    album_count = Album.all.count
    puts ""
    puts "Singers in the database: #{singer_count}"
    puts "Albums in the database: #{album_count}"

    puts ""
    puts "Deleting all albums in the database using Partitioned DML"
    # Note that a Partitioned DML transaction can contain ONLY ONE DML statement.
    # If we want to delete all data in two different tables, we need to do so in two different PDML transactions.
    Album.transaction isolation: :pdml do
      count = Album.delete_all
      puts "Deleted #{count} albums"
    end
    puts ""
    puts "Deleting all singers in the database using normal Read-Write transaction with PDML fallback"
    #
    # This example demonstrates using `isolation: :fallback_to_pdml`.
    #
    # --- HOW IT WORKS ---
    # 1. Initial Attempt: The transaction starts as a normal, atomic, read-write transaction.
    #
    # 2. The Trigger: If that transaction fails with a `TransactionMutationLimitExceededError`,
    #    the adapter automatically catches the error.
    #
    # 3. The Fallback: The adapter then retries the ENTIRE code block in a new,
    #    non-atomic Partitioned DML (PDML) transaction.
    #
    # --- WARNING: CRITICAL USAGE REQUIREMENTS ---
    # This implementation retries the whole transaction block without checking its contents.
    # The user of this feature is responsible for ensuring the following:
    #
    # 1. SINGLE DML STATEMENT: The block SHOULD contain only ONE DML statement.
    #    If it contains more, the PDML retry will fail with a low-level `seqno` error.
    #
    # 2. IDEMPOTENCY: The block MUST be "idempotent" (safe to run multiple times),
    #    as the code may be executed more than once.
    #
    # 3. NON-ATOMIC: The retried PDML transaction is NOT atomic. Do not use this
    #    for multi-step operations that must all succeed or fail together.
    #
    Singer.transaction isolation: :fallback_to_pdml do
      count = Singer.delete_all
      puts "Deleted #{count} singers"
    end
    Singer.transaction isolation: :fallback_to_pdml do
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
end

Application.run
