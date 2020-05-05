# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"
require "models/member"
require "models/membership"
require "models/member_type"
require "models/club"

module ActiveRecord
  module Associations
    class HasOneThroughTest < SpannerAdapter::TestCase
      include SpannerAdapter::Associations::TestHelper

      attr_accessor :club, :member, :member_type

      def setup
        super

        @club = Club.create name:  "Club - 1"
        @member_type = MemberType.create name: "MemberType - 1"
        @member = Member.create name: "Member - 1"
      end

      def teardown
        Member.destroy_all
        Club.destroy_all
        Membership.destroy_all
        MemberType.destroy_all
      end

      def test_has_one_through
        member.club = club
        member.reload
        assert_equal club, member.club
      end

      def test_creating_association_creates_through_record
        member.club = club

        assert_equal member.id, member.membership.member_id
        assert_equal club.id, member.membership.club.id
        assert_equal club, member.club
      end

      def test_set_record_to_nil_should_delete_association
        member.club = club
        member.reload
        assert_equal club, member.club

        member.club = nil
        member.reload
        assert_nil member.membership
        assert_nil member.club
      end

      def test_set_record_after_delete_association
        member.club = club
        member.reload
        assert_equal club, member.club

        member.club = nil
        member.reload
        assert_nil member.membership
        assert_nil member.club

        club = Club.create name: "Club - 2"
        member.club = club
        member.reload
        assert_equal club, member.club
      end

      def test_has_one_through_eager_loading
        member.club = club

        members = Member.includes(:club).all.to_a
        assert_equal 1, members.size
        assert_not_nil assert_no_queries { members[0].club }
      end

      def test_has_one_through_with_where_condition
        member.favourite_club = club
        membership = member.membership
        membership.favourite = true
        membership.save

        member.reload

        assert_equal member.favourite_club, club
      end
    end
  end
end