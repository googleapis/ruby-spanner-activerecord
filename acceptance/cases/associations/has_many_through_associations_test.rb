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
    class HasManyThroughTest < SpannerAdapter::TestCase
      include SpannerAdapter::Associations::TestHelper

      attr_accessor :club, :member_one, :member_two

      def setup
        super

        @club = Club.create name:  "Club - 1"
        @member_one = Member.create name: "Member - 1"
        @member_two = Member.create name: "Member - 2"
      end

      def teardown
        Member.destroy_all
        Club.destroy_all
      end

      def test_has_many_through_create_record
        assert club.members.create!(name: "Member - 3")
      end

      def test_through_association_with_joins
        club.members = [member_one, member_two]
        assert_equal [club, club], Club.where(id: club.id).joins(:members).to_a
      end

      def test_set_record_after_delete_association
        club.members = [member_one, member_two]
        club.reload
        assert_equal 2, club.members.count

        club.members = []
        club.reload
        assert_empty club.members
      end

      def test_has_many_through_eager_loading
        club.members = [member_one, member_two]

        clubs = Club.includes(:members).all.to_a
        assert_equal 1, clubs.size
        assert_not_nil assert_no_queries { clubs[0].members }
      end
    end
  end
end