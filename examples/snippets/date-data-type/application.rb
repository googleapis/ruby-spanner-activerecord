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
    # Get all singers order by birthdate
    puts ""
    puts "Listing all singers order by birth date:"
    Singer.all.order(:birth_date).each do |singer|
      puts "#{"#{singer.first_name} #{singer.last_name}".ljust 30}#{singer.birth_date}"
    end

    # Update the birthdate of a random singer using the current system time. Any time and timezone information will be
    # lost after saving the record as a DATE only contains the year, month and day-of-month information.
    singer = Singer.all.sample
    singer.update birth_date: Time.now
    singer.reload
    puts ""
    puts "Updated birth date to current system time:"
    puts "#{"#{singer.first_name} #{singer.last_name}".ljust 30}#{singer.birth_date}"
  end
end

Application.run
