# Copyright 2023 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "io/console"
require_relative "../config/environment"
require_relative "models/singer"
require_relative "models/album"
require_relative "models/track"

class Application
  def self.run
    # List all singers, albums and tracks.
    list_singers_albums_tracks

    # Create a new album with some tracks.
    create_new_album

    # Try to update the singer of an album. This is not possible as albums are interleaved in singers.
    update_singer_of_album

    # Try to delete a singer that has at least one album. This is NOT possible as albums is NOT marked with
    # ON DELETE CASCADE.
    delete_singer_with_albums

    # Try to delete an album that has at least one track. This IS possible as tracks IS marked with
    # ON DELETE CASCADE.
    delete_album_with_tracks

    puts ""
    puts "Press any key to end the application"
    STDIN.getch
  end

  def self.find_singer
    singerid = Singer.all.sample.singerid

    singer = Singer.find singerid
    puts "Found singer: #{singer.first_name} #{singer.last_name}"
  end

  def self.find_album
    singer = Singer.all.sample
    albumid = singer.albums.sample.albumid

    album = Album.find [singer.singerid, albumid]
    puts "Found album: #{album.title}"
  end

  def self.list_singers_albums
    puts ""
    puts "Listing all singers with corresponding albums and tracks"
    Singer.all.order("last_name, first_name").each do |singer|
      puts "#{singer.first_name} #{singer.last_name} has #{singer.albums.count} albums:"
      singer.albums.order("title").each do |album|
        puts "  #{album.title} has #{album.tracks.count} tracks:"
        album.tracks.each do |track|
          puts "    #{track.title}"
        end
      end
    end
  end

  def self.create_new_album
    # Create a new album with some tracks.
    puts ""
    singer = Singer.all.sample
    puts "Creating a new album for #{singer.first_name} #{singer.last_name}"
    album = singer.albums.build title: "New Title"
    # NOTE: When adding multiple elements to a collection, you *MUST* set the primary key value (i.e. trackid).
    # Otherwise, ActiveRecord thinks that you are adding the same record multiple times and will only add one.
    album.tracks.build title: "Track 1", duration: 3.5, singer: singer, trackid: Track.next_sequence_value
    album.tracks.build title: "Track 2", duration: 3.6, singer: singer, trackid: Track.next_sequence_value
    # This will save the album and corresponding tracks in one transaction.
    album.save!

    album.reload
    puts "Album #{album.title} has #{album.tracks.count} tracks:"
    album.tracks.order("title").each do |track|
      puts "  #{track.title} with duration #{track.duration}"
    end
  end

  def self.update_singer_of_album
    # It is not possible to change the singer of an album or the album of a track. This is because the associations
    # between these are not traditional foreign keys, but an immutable parent-child relationship.
    album = Album.all.sample
    new_singer = Singer.all.where.not(singerid: album.singer).sample
    # This will fail as we cannot assign a new singer to an album as it is an INTERLEAVE IN PARENT relationship.
    begin
      album.update! singer: new_singer
      raise StandardError, "Unexpected error: Updating the singer of an album should not be possible."
    rescue ActiveRecord::StatementInvalid
      puts ""
      puts "Failed to update the singer of an album. This is expected."
    end
  end

  def self.delete_singer_with_albums
    # Deleting a singer that has albums is not possible, as the INTERLEAVE IN PARENT of albums is not marked with
    # ON DELETE CASCADE.
    singer = Album.all.sample.singer
    begin
      singer.delete
      raise StandardError, "Unexpected error: Updating the singer of an album should not be possible."
    rescue ActiveRecord::StatementInvalid
      puts ""
      puts "Failed to delete a singer that has #{singer.albums.count} albums. This is expected."
    end
  end

  def self.delete_album_with_tracks
    # Deleting an album with tracks is supported, as the INTERLEAVE IN PARENT relationship between tracks and albums is
    # marked with ON DELETE CASCADE.
    puts ""
    puts "Total track count: #{Track.count}"
    album = Track.all.sample.album
    puts "Deleting album #{album.title} with #{album.tracks.count} tracks"
    album.delete
    puts "Total track count after deletion: #{Track.count}"
  end
end

Application.run
