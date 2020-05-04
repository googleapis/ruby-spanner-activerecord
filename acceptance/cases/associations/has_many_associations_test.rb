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
require "models/firm"
require "models/account"
require "models/transaction"
require "models/department"
require "models/customer"

module ActiveRecord
  module Associations
    class HasManyTest < SpannerAdapter::TestCase
      include SpannerAdapter::Associations::TestHelper

      attr_accessor :customer

      def setup
        super

        @customer = Customer.create name: "Customer - 1"

        Account.create name: "Account - 1", customer: customer, credit_limit: 100
        Account.create name: "Account - 2", customer: customer, credit_limit: 200
      end

      def teardown
        Customer.destroy_all
        Account.destroy_all
      end

      def test_has_many
        assert_equal 2, customer.accounts.count
        assert_equal customer.accounts.pluck(:credit_limit).sort, [100, 200]
      end

      def test_finding_using_associated_fields
        assert_equal Account.where(customer_id: customer.id).to_a, customer.accounts.to_a
      end

      def test_successful_build_association
        account = customer.accounts.build(name: "Account - 3", credit_limit: 1000)
        assert account.save

        customer.reload
        assert_equal account, customer.accounts.find(account.id)
      end

      def test_create_and_destroy_associated_records
        customer2 = Customer.new name: "Customer - 2"
        customer2.accounts.build name: "Account - 11", credit_limit: 100
        customer2.accounts.build name: "Account - 12", credit_limit: 200
        customer2.save!

        customer2.reload

        assert_equal 2, customer2.accounts.count
        assert_equal 4, Account.count

        customer2.accounts.destroy_all
        customer2.reload

        assert_equal 0, customer2.accounts.count
        assert_equal 2, Account.count
      end

      def test_create_and_delete_associated_records
        customer2 = Customer.new name: "Customer - 2"
        customer2.accounts.build name: "Account - 11", credit_limit: 100
        customer2.accounts.build name: "Account - 12", credit_limit: 200
        customer2.save!

        customer2.reload

        assert_equal 2, customer2.accounts.count
        assert_equal 4, Account.count

        assert_equal 2, customer2.accounts.delete_all
        customer2.reload

        assert_equal 0, customer2.accounts.count
        assert_equal 2, Account.where(customer_id: nil).count
      end

      def test_update_associated_records
        count = customer.accounts.update_all(name: "Account - Update", credit_limit: 1000)
        assert_equal customer.accounts.count, count

        customer.reload
        customer.accounts.each do |account|
          assert_equal "Account - Update", account.name
          assert_equal 1000, account.credit_limit
        end
      end

      def test_fetch_associated_recoed_with_order
        accounts = customer.accounts.order(credit_limit: :desc)
        assert_equal [200, 100], accounts.pluck(:credit_limit)

        accounts = customer.accounts.order(credit_limit: :asc)
        assert_equal [100, 200], accounts.pluck(:credit_limit)
      end

      def test_set_counter_cache
        account = Account.first
        account.transactions.create!(amount: 10)
        account.transactions.create!(amount: 20)

        account.reload
        assert_equal 2, account.transactions_count
      end
    end
  end
end