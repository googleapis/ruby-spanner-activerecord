# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "io/console"
require_relative "../config/environment"
require_relative "models/singer"

class Application
  def self.run
    puts ""
    puts "Listing all singers:"
    Singer.all.order("last_name, first_name").each do |singer|
      puts singer.full_name
    end

    # Create a new singer and print out the full name.
    singer = Singer.create first_name: "Alice", last_name: "Rees"
    singer.reload
    puts ""
    puts "Singer created: #{singer.full_name}"

    # Update the last name of the singer and print out the full name.
    singer.update last_name: "Rees-Goodwin"
    singer.reload
    puts ""
    puts "Singer updated: #{singer.full_name}"

    puts ""
    puts "Press any key to end the application"
    $stdin.getch
  end
end

Application.run
