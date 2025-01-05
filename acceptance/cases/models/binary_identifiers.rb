# Copyright 2025 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"
require "test_helpers/with_separate_database"
require_relative "../../models/user"
require_relative "../../models/binary_project"

module Models
  class DefaultValueTest < SpannerAdapter::TestCase
    include TestHelpers::WithSeparateDatabase

    def setup
      super

      connection.create_table :users, id: :binary do |t|
        t.string :email, null: false
        t.string :full_name, null: false
      end
      connection.create_table :binary_projects, id: :binary do |t|
        t.string :name, null: false
        t.string :description, null: false
        t.binary :owner_id, null: false
        t.foreign_key :users, column: :owner_id
      end
    end

    def test_includes_works
      user = User.create!(
        email: "test@example.com",
        full_name: "Test User"
      )
      3.times do |i|
        Project.create!(
          name: "Project #{i}",
          description: "Description #{i}",
          owner: user
        )
      end

      # First verify the association works without includes
      projects = Project.all
      assert_equal 3, projects.count

      # Compare the base64 content instead of the StringIO objects
      first_project = projects.first
      assert_equal to_base64(user.id), to_base64(first_project.owner_id)

      # Now verify includes is working
      query_count = count_queries do
        loaded_projects = Project.includes(:owner).to_a
        loaded_projects.each do |project|
          # Access the owner to ensure it's preloaded
          assert_equal user.full_name, project.owner.full_name
        end
      end

      # Spanner should execute 2 queries: one for projects and one for users
      assert_equal 2, query_count
    end

    private

    def to_base64 buffer
      buffer.rewind
      value = buffer.read
      Base64.strict_encode64 value.force_encoding("ASCII-8BIT")
    end

    def count_queries(&block)
      count = 0
      counter_fn = ->(name, started, finished, unique_id, payload) {
        unless %w[CACHE SCHEMA].include?(payload[:name])
          count += 1
        end
      }

      ActiveSupport::Notifications.subscribed(counter_fn, "sql.active_record", &block)
      count
    end
  end
end
