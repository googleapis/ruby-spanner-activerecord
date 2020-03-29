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