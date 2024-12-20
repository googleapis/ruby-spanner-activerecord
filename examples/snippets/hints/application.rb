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
    puts ""
    puts "Listing all singers using additional parallelism:"
    # A statement hint must be prefixed with 'statement_hint:'
    Singer.optimizer_hints("statement_hint: @{USE_ADDITIONAL_PARALLELISM=TRUE}")
          .order("last_name, first_name").each do |singer|
      puts singer.full_name
    end

    puts ""
    puts "Listing all singers using the index on full_name:"
    # All table hints must be prefixed with 'table_hint:'.
    # Queries may contain multiple table hints.
    Singer.optimizer_hints("table_hint: singers@{FORCE_INDEX=index_singers_on_full_name}")
          .order("full_name").each do |singer|
      puts singer.full_name
    end

    puts ""
    puts "Listing all singers with at least one album that starts with 'blue':"
    # Join hints cannot be specified using an optimizer_hint. Instead, the join can
    # be specified using a string that includes the join hint.
    Singer.joins("INNER JOIN @{JOIN_METHOD=HASH_JOIN} albums " \
                 "on singers.id=albums.singer_id AND albums.title LIKE 'blue%'")
          .distinct.order("last_name, first_name").each do |singer|
      puts singer.full_name
    end

    puts ""
    puts "Press any key to end the application"
    $stdin.getch
  end
end

Application.run
