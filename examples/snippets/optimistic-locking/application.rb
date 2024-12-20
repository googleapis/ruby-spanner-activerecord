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
    # Get a random singer and then update the singer in a separate thread.
    # This simulates a concurrent update of the same record by two different processes.
    singer = Singer.all.sample

    puts ""
    puts "Singer #{singer.first_name} #{singer.last_name} with version #{singer.lock_version} loaded"

    t = Thread.new do
      # Load the singer in the separate thread into a separate variable.
      singer2 = Singer.find singer.id
      singer2.update last_name: "Rashford"
      puts ""
      puts "Updated the last name of the singer to #{singer2.last_name}"
    end
    t.join

    # Now try to update the singer in the main thread. This will fail, as the lock_version number has been increased
    # by the update in the separate thread.
    begin
      singer.update last_name: "Drake"
    rescue ActiveRecord::StaleObjectError
      puts ""
      puts "Updating the singer in the main thread failed with a StaleObjectError"
    end

    singer.reload
    puts "Reloaded singer data: #{singer.first_name} #{singer.last_name}, version: #{singer.lock_version}"

    puts ""
    puts "Press any key to end the application"
    $stdin.getch
  end
end

Application.run
