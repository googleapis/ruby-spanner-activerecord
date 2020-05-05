# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"
require "models/account"
require "models/customer"
require "models/firm"

module ActiveRecord
  module Model
    class CalculationQueryTest < SpannerAdapter::TestCase
      include SpannerAdapter::Associations::TestHelper

      attr_accessor :customer, :accounts

      def setup
        super

        @customer = Customer.new name: "Customer - 1"
        @accounts = []

        [10, 21, 1007, 3].each_with_index do |credit_limit, i|
          @accounts << Account.create!(
            name: "Account#{i}", customer: customer, credit_limit: credit_limit
          )
        end
      end

      def teardown
        super

        Account.delete_all
        Customer.delete_all
      end

      def test_pluck_single_field
        expected_ids = @accounts.map(&:id).sort
        ids = Account.pluck(:id).sort
        assert_equal expected_ids, ids
      end

      def test_pluck_multi_fields
        expected_values = @accounts.sort_by{|a| a.id }.map{|a| [a.id, a.name]}

        values = Account.pluck(:id, :name).sort_by{|v| v.first }
        assert_equal expected_values, values
      end

      def test_get_ids
        expected_ids = @accounts.map(&:id).sort

        assert_equal expected_ids, Account.ids.sort
      end

      def test_pick_one_field
        assert_equal "Account0", Account.order(:name).pick(:name)
      end

      def test_pick_two_field
        assert_equal ["Account0", 10], Account.order(:name).pick(:name, :credit_limit)
      end

      def test_count_all
        assert_equal 4, Account.count(:all)
        assert_equal 4, Account.count(:all)
      end

      def test_distinct_count
        Account.create name: "Account-101", credit_limit: 3
        assert_equal 4, Account.distinct.count(:credit_limit)
      end

      def test_group_count
        Account.create name: "Account-101", credit_limit: 3

        expected_values = { 3 => 2, 10 => 1, 21 => 1, 1007 => 1}
        assert_equal expected_values, Account.group(:credit_limit).count
      end

      def test_sum_field
        assert_equal 1041, Account.sum(:credit_limit)
      end

      def test_resolve_aliased_attributes
        assert_equal 1041, Account.sum(:available_credit)
      end

      def test_average_field
        assert_equal 260.25, Account.average(:credit_limit)
      end

      def test_get_maximum_of_field
        assert_equal 1007, Account.maximum(:credit_limit)
      end

      def test_get_maximum_of_field_with_include
        customer2 = Customer.create! name: "Customer - 2"
        firm = Firm.create name: "Firm - 1"
        Account.create!(customer: customer2, credit_limit: 103, firm: firm)
        Account.create!(customer: customer2, credit_limit: 24, firm: firm)

        assert_equal 103, Account.where("customer_id = ?", customer2.id).includes(:firm).maximum(:credit_limit)
      end

      def test_get_minimum_of_field
        assert_equal 3, Account.minimum(:credit_limit)
      end

      def test_calculate_count
        assert_equal 4, Account.calculate(:count, "*")
        assert_equal 4, Account.calculate(:count, :all)
      end

      def test_caclulate_sum
        assert_equal 1041, Account.calculate(:sum, :credit_limit)
      end

      def test_caclulate_average
        assert_equal 260.25, Account.calculate(:average, :credit_limit)
      end
    end
  end
end