# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"
require "models/firm"
require "models/account"
require "models/department"


module ActiveRecord
  module Associations
    class HasOneTest < SpannerAdapter::TestCase
      include SpannerAdapter::Associations::TestHelper

      attr_accessor :singer, :album1, :album2, :track1_1, :track1_2, :track2_1, :track2_2

      def setup
        super

        @singer = Singer.create first_name: "FirstName1", last_name: "LastName1"

        @album2 = Album.create title: "Title2", singer: singer
        @album1 = Album.create title: "Title1", singer: singer

        @track2_1 = Track.create title: "Title2_1", album: album2, duration: 3.6
        @track2_2 = Track.create title: "Title2_2", album: album2, duration: 3.3
        @track1_1 = Track.create title: "Title1_1", album: album1, duration: 4.5
        @track1_2 = Track.create title: "Title1_2", album: album1

        @singer.reload
        @album1.reload
        @album2.reload
        @track1_1.reload
        @track2_1.reload
        @track1_2.reload
        @track2_2.reload
      end

      def teardown
        Album.destroy_all
        Singer.destroy_all
      end

      def test_has_one
        assert_equal singer, album1.singer
        assert_equal singer, album2.singer

        assert_equal album1, track1_1.album
        assert_equal album1, track1_2.album
        assert_equal album2, track2_1.album
        assert_equal album2, track2_2.album
      end

      def test_has_one_does_not_use_order_by
        sql_log = capture_sql { album1.singer }
        assert sql_log.all? { |sql| !/order by/i.match?(sql) }, "ORDER BY was used in the query: #{sql_log}"
      end

      def test_find_using_primary_key
        assert_equal Singer.find_by(singerid: singer.id), album1.singer
      end

      def test_successful_build_association


        account = firm.build_account(credit_limit: 1000)
        assert account.save

        firm.reload
        assert_equal account, firm.account
      end

      def test_delete_associated_records
        assert_equal account, firm.account

        firm.account.destroy
        firm.reload
        assert_nil firm.account
      end

      def test_polymorphic_association
        assert_equal 0, firm.departments.count

        firm.departments.create(name: "Department - 1")
        firm.reload

        assert_equal 1, firm.departments.count
        assert_equal "Department - 1", firm.departments.first.name
      end
    end
  end
end
