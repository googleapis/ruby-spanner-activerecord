# The MIT License (MIT)
#
# Copyright (c) 2020 Google LLC.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# ITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

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