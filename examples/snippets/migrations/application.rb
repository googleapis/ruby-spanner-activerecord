# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "io/console"
require_relative "../config/environment"

class Application
  def self.run
    puts ""
    puts "Created database with the following tables:"
    sql = "SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_CATALOG='' AND TABLE_SCHEMA=''"
    tables = ActiveRecord::Base.connection.raw_connection.execute_query sql
    tables.rows.each do |row|
      puts row[:TABLE_NAME]
    end

    puts ""
    puts "Press any key to end the application"
    $stdin.getch
  end
end

Application.run
