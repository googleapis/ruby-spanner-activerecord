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
    # Creating a single record without an explicit transaction will automatically save it to the database.
    # It is not recommended to call Entity.create repeatedly to insert multiple records, as each call will
    # use a separate Spanner transaction. Instead multiple records should be created by passing an array of
    # entities to the Entity.create method.
    singer = Singer.create first_name: "Dave", last_name: "Allison"
    puts ""
    puts "Created singer #{singer.first_name} #{singer.last_name} with id #{singer.id}"
    puts ""

    # Creating multiple records without an explicit transaction will automatically save all the records using
    # one Spanner transaction and return the ids of the created records. This is the recommended way to create
    # a batch of entities.
    singers = Singer.create [
      { first_name: "Alice", last_name: "Wendelson" },
      { first_name: "Nick", last_name: "Rainbow" },
      { first_name: "Elena", last_name: "Quick" }
    ]
    puts "Created a batch of #{singers.length} singers:"
    singers.each do |s|
      puts "  Created singer #{s.first_name} #{s.last_name} with id #{s.id}"
    end

    puts ""
    puts "Press any key to end the application"
    $stdin.getch
  end
end

Application.run
