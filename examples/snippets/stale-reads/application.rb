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
    # Get a random album.
    album = Album.all.sample

    # Get a valid timestamp from the Cloud Spanner server that we can use to specify a timestamp bound.
    timestamp = ActiveRecord::Base.connection.select_all("SELECT CURRENT_TIMESTAMP AS ts")[0]["ts"]

    # Update the name of the album and then read the version of the album before the update.
    album.update title: "New title"

    # The timestamp should be specified in the format '2021-09-07T15:22:10.123456789Z'
    timestamp_string = timestamp.xmlschema 9

    # Read the album at a specific timestamp.
    album_previous_version = Album.optimizer_hints("read_timestamp: #{timestamp_string}").find_by id: album.id
    album = album.reload

    puts ""
    puts "Updated album title: #{album.title}"
    puts "Previous album version title: #{album_previous_version.title}"

    # Read the same album using a minimum read timestamp. It could be that we get the first version
    # of the row, but it could also be that we get the updated row.
    album_min_read_timestamp = Album.optimizer_hints("min_read_timestamp: #{timestamp_string}").find_by id: album.id
    puts ""
    puts "Updated album title: #{album.title}"
    puts "Min-read timestamp title: #{album_min_read_timestamp.title}"

    # Staleness can also be specified as a number of seconds. The number of seconds may contain a fraction.
    # The following reads the album version at exactly 1.5 seconds ago. That will normally be nil, as the
    # row did not yet exist at that moment.
    album_exact_staleness = Album.optimizer_hints("exact_staleness: 1.5").find_by id: album.id

    puts ""
    puts "Updated album title: #{album.title}"
    puts "Title 1.5 seconds ago: #{album_exact_staleness&.title}"

    # You can also specify a max staleness. The server will determine the best timestamp to use for the read.
    album_max_staleness = Album.optimizer_hints("max_staleness: 10").find_by id: album.id

    puts ""
    puts "Updated album title: #{album.title}"
    puts "Title somewhere during the last 10 seconds: #{album_max_staleness&.title}"

    puts ""
    puts "Press any key to end the application"
    STDIN.getch
  end
end

Application.run
