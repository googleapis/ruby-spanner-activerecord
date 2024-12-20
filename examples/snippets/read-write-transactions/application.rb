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
    from_album = nil
    to_album = nil
    # Use a read/write transaction to execute multiple statements as an atomic unit.
    ActiveRecord::Base.transaction do
      # Transfer a marketing budget of 10,000 from one album to another.
      from_album = Album.all.sample
      to_album = Album.where.not(id: from_album.id).sample

      puts ""
      puts "Transferring 10,000 marketing budget from #{from_album.title} (#{from_album.marketing_budget}) " \
           "to #{to_album.title} (#{to_album.marketing_budget})"
      from_album.update marketing_budget: from_album.marketing_budget - 10000
      to_album.update marketing_budget: to_album.marketing_budget + 10000
    end
    puts ""
    puts "Budgets after update:"
    puts "Marketing budget #{from_album.title}: #{from_album.reload.marketing_budget}"
    puts "Marketing budget #{to_album.title}: #{to_album.reload.marketing_budget}"

    puts ""
    puts "Press any key to end the application"
    $stdin.getch
  end
end

Application.run
