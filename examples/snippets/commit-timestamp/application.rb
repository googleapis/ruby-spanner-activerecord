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
    format = "%Y-%m-%dT%k:%M:%S.%N"
    singer = nil
    album = nil
    ActiveRecord::Base.transaction do
      # Create a singer and album with a commit timestamp that is set by Cloud Spanner.
      # Use the `:commit_timestamp` symbol to instruct the Spanner ActiveRecord adapter to update the attribute to the
      # commit timestamp of the transaction. Note that the value is not readable before the transaction has been
      # committed. The commit timestamp of the following two records will be equal, as they are created in the same
      # transaction.
      singer = Singer.create first_name: "Pete", last_name: "Allison", last_updated: :commit_timestamp
      album = singer.albums.create title: "Dear Repayment", last_updated: :commit_timestamp
    end
    # Reload the records to get the actual commit timestamp values.
    singer.reload
    album.reload

    puts ""
    puts "Singer and album created:"
    puts "#{singer.first_name} #{singer.last_name} (Last updated: #{singer.last_updated.strftime format})"
    puts "   #{album.title} (Last updated: #{album.last_updated.strftime format})"

    # The commit timestamp can also be set in an implicit transaction. Note that the following two statements will
    # create two separate (implicit) transactions, and the commit timestamps of the two records will now be slightly
    # different.
    singer.update last_updated: :commit_timestamp
    album.update last_updated: :commit_timestamp
    singer.reload
    album.reload
    puts ""
    puts "Singer and album updated:"
    puts "#{singer.first_name} #{singer.last_name} (Last updated: #{singer.last_updated.strftime format})"
    puts "   #{album.title} (Last updated: #{album.last_updated.strftime format})"

    puts ""
    puts "Press any key to end the application"
    $stdin.getch
  end
end

Application.run
