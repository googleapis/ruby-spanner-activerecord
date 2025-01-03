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
    # Creating multiple records without an explicit transaction will automatically save all the records using
    # one Spanner transaction and return the ids of the created records. The implicit transaction that is created
    # by the Spanner ActiveRecord adapter will automatically use Mutations for the bulk insert. This is a lot more
    # efficient than a list of DML statements.
    singers = Singer.create [
      { first_name: "Alice", last_name: "Wendelson" },
      { first_name: "Nick", last_name: "Rainbow" },
      { first_name: "Elena", last_name: "Quick" }
    ]
    puts ""
    puts "Created a batch of #{singers.length} singers using an implicit transaction:"
    singers.each do |s|
      puts "  Created singer #{s.first_name} #{s.last_name} with id #{s.id}"
    end

    # If you need to create multiple records of different types, you can use an explicit transaction with isolation
    # level `:buffered_mutations`. This Spanner-specific isolation level will instruct the read/write transaction to
    # use Mutations instead of DML.
    singers = nil
    albums = nil
    ActiveRecord::Base.transaction isolation: :buffered_mutations do
      singers = Singer.create [
        { first_name: "Boris", last_name: "Carelia" },
        { first_name: "Yvonne", last_name: "McKenzie" },
        { first_name: "Wendy", last_name: "Bravo" }
      ]
      albums = Album.create [
        { title: "Hot Potatoes", singer: singers[0] },
        { title: "Lazy Street", singer: singers[0] },
        { title: "Daily Glass", singer: singers[1] },
        { title: "Happy Windows", singer: singers[2] },
        { title: "Generous Street", singer: singers[2] }
      ]
    end
    puts ""
    puts "Created a batch of #{singers.length} singers and #{albums.length} " \
         "albums using a transaction with buffered mutations:"
    singers.each do |s|
      puts "  Created singer #{s.first_name} #{s.last_name} with id #{s.id}"
      s.albums.each do |a|
        puts "    with album #{a.title} with id #{a.id}"
      end
    end
  end
end

Application.run
