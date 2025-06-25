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
    # --- USAGE REQUIREMENTS ---
    # This implementation retries the whole transaction block without checking its contents.
    # The user of this feature is responsible for ensuring the following:
    #
    # 1. SINGLE DML STATEMENT: The block should contain only ONE DML statement.
    #    If it contains more, the PDML retry will fail with a low-level `seqno` error.
    #
    # 2. IDEMPOTENCY: The DML statement must be idempotent. See https://cloud.google.com/spanner/docs/dml-partitioned#partitionable-idempotent for more information. # rubocop:disable Layout/LineLength
    #
    # 3. NON-ATOMIC: The retried PDML transaction is NOT atomic. Do not use this
    #    for multi-step operations that must all succeed or fail together.
    #
    Singer.transaction isolation: :fallback_to_pdml do
      count = Singer.delete_all
      puts "Deleted #{count} singers"
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
