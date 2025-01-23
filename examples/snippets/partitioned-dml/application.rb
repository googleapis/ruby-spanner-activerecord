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
