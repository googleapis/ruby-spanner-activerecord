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
    # Use a read-only transaction to execute multiple reads at the same commit timestamp.
    # The Spanner ActiveRecord adapter supports the custom isolation level :read_only that
    # will start a read-only Spanner transaction with a strong timestamp bound.
    album1 = nil
    album2 = nil
    ActiveRecord::Base.transaction isolation: :read_only do
      # Read two random titles.
      album1 = Album.all.sample
      album2 = Album.where.not(id: album1.id).sample
      puts ""
      puts "Album title 1: #{album1.title}"
      puts "Album title 2: #{album2.title}"

      # Update the title of one of the albums in a separate transaction.
      puts ""
      puts "Updating the title of #{album1.title} in a separate transaction"
      t = Thread.new { album1.update title: "New title" }
      t.join

      puts ""
      puts "Reloading the albums in the read-only transaction. The updated title is not visible."
      puts "Album title 1: #{album1.reload.title}"
      puts "Album title 2: #{album2.reload.title}"
    end
    puts ""
    puts "Reloading the albums **AFTER** the read-only transaction. The updated title is now visible."
    puts "Album title 1: #{album1.reload.title}"
    puts "Album title 2: #{album2.reload.title}"

    # You can also execute a stale read with ActiveRecord. Specify a hash as the isolation level with one of
    # the following options:
    # * timestamp: Read data at a specific timestamp.
    # * staleness: Read data at a specific staleness measured in seconds.

    # Get a valid timestamp from the server to use for the transaction.
    timestamp = ActiveRecord::Base.connection.select_all("SELECT CURRENT_TIMESTAMP AS ts")[0]["ts"]
    puts ""
    puts "Read data at timestamp #{timestamp}"
    ActiveRecord::Base.transaction isolation: { timestamp: timestamp } do
      puts "Album title 1: #{album1.reload.title}"
      puts "Album title 2: #{album2.reload.title}"
    end

    puts ""
    puts "Read data with staleness 30 seconds"
    ActiveRecord::Base.transaction isolation: { staleness: 30 } do
      begin
        puts "Album title 1: #{album1.reload.title}"
      rescue StandardError => e
        # The table will (in almost all cases) not be found, because the timestamp that is being used to read
        # the data will be before the table was created. This will therefore cause a 'Table not found' error.
        puts "Reading data with 30 seconds staleness failed with error: #{e.message}"
        puts ""
        puts "This error is expected."
      end
    end

    puts ""
    puts "Press any key to end the application"
    STDIN.getch
  end
end

Application.run
