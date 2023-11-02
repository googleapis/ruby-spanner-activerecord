# Copyright 2023 Google LLC
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
    puts ""
    puts "Query all Albums and include a request tag"
    albums = Album.annotate("request_tag: query-all-albums").all
    puts "Queried #{albums.length} albums using a request tag"

    puts ""
    puts "Query all Albums in a transaction and include a request tag and a transaction tag"
    Album.transaction do
      albums = Album.annotate("request_tag: query-all-albums", "transaction_tag: sample-transaction").all
      puts "Queried #{albums.length} albums using a request and a transaction tag"
    end

    puts ""
    puts "Press any key to end the application"
    STDIN.getch
  end
end

Application.run
