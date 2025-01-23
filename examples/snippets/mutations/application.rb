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
    # This transaction uses Mutations instead of DML. That means that any data changes are not readable during
    # the transaction itself, as the mutations are buffered locally in the client and only sent to Spanner
    # when the transaction is committed.
    ActiveRecord::Base.transaction isolation: :buffered_mutations do
      # Transfer a marketing budget of 10,000 from one album to another.
      from_album = Album.all.sample
      to_album = Album.where.not(id: from_album.id).sample

      puts ""
      puts "Transferring 10,000 marketing budget from #{from_album.title} (#{from_album.marketing_budget}) " \
           "to #{to_album.title} (#{to_album.marketing_budget})"
      from_album.update marketing_budget: from_album.marketing_budget - 10000
      to_album.update marketing_budget: to_album.marketing_budget + 10000

      # The above change is not sent to the database before the transaction is committed.
      puts ""
      puts "Budgets before commit:"
      puts "Marketing budget #{from_album.title}: #{from_album.reload.marketing_budget}"
      puts "Marketing budget #{to_album.title}: #{to_album.reload.marketing_budget}"
    end
    puts ""
    puts "Budgets after commit:"
    puts "Marketing budget #{from_album.title}: #{from_album.reload.marketing_budget}"
    puts "Marketing budget #{to_album.title}: #{to_album.reload.marketing_budget}"
  end
end

Application.run
